defmodule Citadel.Kernel.KernelSnapshot do
  @moduledoc """
  Single serialized writer for aggregate `DecisionSnapshot` publication.

  Hot-path readers use the read surface published by this owner rather than
  issuing synchronous mailbox reads on every decision pass.
  """

  use GenServer

  alias Citadel.DecisionSnapshot
  alias Citadel.KernelEpochUpdate
  alias Citadel.ObservabilityContract.Telemetry
  alias Citadel.Kernel.SystemClock

  @surface_suffix :decision_snapshot
  @surface_table_key :current
  @allowed_staleness_classes [
    :fresh_required,
    :bounded_stale_allowed,
    :rebuild_required,
    :reject_stale
  ]

  @type state :: %{
          clock: module(),
          read_surface_key: term(),
          read_surface_table: :ets.tid(),
          snapshot: DecisionSnapshot.t()
        }

  @type read_surface_discovery :: %{table: :ets.tid(), table_key: :current}

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def publish_epoch_update(server \\ __MODULE__, %KernelEpochUpdate{} = update) do
    GenServer.cast(server, {:publish_epoch_update, update})
  end

  def snapshot(server \\ __MODULE__) do
    GenServer.call(server, :snapshot)
  end

  def current_snapshot(name \\ __MODULE__) do
    case fetch_snapshot(name) do
      {:ok, snapshot} ->
        snapshot

      {:error, reason} ->
        invariant_failure!("read surface unavailable: #{inspect(reason)}")
    end
  end

  def read_surface_key(name \\ __MODULE__), do: {__MODULE__, name, @surface_suffix}

  def read_surface_info(name \\ __MODULE__) do
    discovery = read_surface_discovery!(name)

    %{
      storage: :ets,
      table: discovery.table,
      table_key: discovery.table_key,
      discovery_key: read_surface_key(name),
      protection: :ets.info(discovery.table, :protection),
      read_concurrency?: :ets.info(discovery.table, :read_concurrency)
    }
  end

  def read_snapshot(name \\ __MODULE__, opts \\ []) do
    with {:ok, staleness_class} <- staleness_class(opts),
         {:ok, snapshot} <- fetch_snapshot(name) do
      evaluate_staleness(snapshot, staleness_class, opts)
    end
  end

  @impl true
  def init(opts) do
    clock = Keyword.get(opts, :clock, SystemClock)
    name = Keyword.get(opts, :name, __MODULE__)
    read_surface_key = Keyword.get(opts, :read_surface_key, read_surface_key(name))

    read_surface_table =
      Keyword.get_lazy(opts, :read_surface_table, fn ->
        :ets.new(__MODULE__, [:set, :protected, {:read_concurrency, true}])
      end)

    snapshot =
      DecisionSnapshot.new!(%{
        snapshot_seq: Keyword.get(opts, :snapshot_seq, 0),
        captured_at: clock.utc_now(),
        policy_version: Keyword.get(opts, :policy_version, "policy/uninitialized"),
        policy_epoch: Keyword.get(opts, :policy_epoch, 0),
        topology_epoch: Keyword.get(opts, :topology_epoch, 0),
        scope_catalog_epoch: Keyword.get(opts, :scope_catalog_epoch, 0),
        service_admission_epoch: Keyword.get(opts, :service_admission_epoch, 0),
        project_binding_epoch: Keyword.get(opts, :project_binding_epoch, 0),
        boundary_epoch: Keyword.get(opts, :boundary_epoch, 0),
        extensions: Keyword.get(opts, :extensions, %{})
      })

    publish_read_surface(read_surface_key, read_surface_table, snapshot)

    {:ok,
     ensure_invariants!(%{
       clock: clock,
       read_surface_key: read_surface_key,
       read_surface_table: read_surface_table,
       snapshot: snapshot
     })}
  end

  @impl true
  def handle_cast({:publish_epoch_update, %KernelEpochUpdate{} = update}, state) do
    backlog = mailbox_depth()
    lag_ms = DateTime.diff(state.clock.utc_now(), update.updated_at, :millisecond)

    :telemetry.execute(
      Telemetry.event_name(:kernel_snapshot_lag),
      %{backlog: backlog, lag_ms: max(lag_ms, 0)},
      %{}
    )

    case apply_update(state.snapshot, update, state.clock.utc_now()) do
      {:unchanged, snapshot} ->
        {:noreply, %{state | snapshot: snapshot}}

      {:updated, snapshot} ->
        publish_read_surface(state.read_surface_key, state.read_surface_table, snapshot)
        {:noreply, ensure_invariants!(%{state | snapshot: snapshot})}
    end
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    {:reply, state.snapshot, state}
  end

  defp apply_update(%DecisionSnapshot{} = snapshot, %KernelEpochUpdate{} = update, captured_at) do
    current_epoch = Map.fetch!(snapshot, update.constituent)
    updated_policy_version = policy_version(snapshot, update)

    cond do
      update.epoch < current_epoch ->
        invariant_failure!(
          "received epoch regression for #{inspect(update.constituent)}: current=#{current_epoch} update=#{update.epoch}"
        )

      update.constituent == :policy_epoch and
        update.epoch == current_epoch and
          updated_policy_version != snapshot.policy_version ->
        invariant_failure!(
          "received policy version drift without policy_epoch advancement: current=#{inspect(snapshot.policy_version)} update=#{inspect(updated_policy_version)}"
        )

      current_epoch == update.epoch and updated_policy_version == snapshot.policy_version ->
        {:unchanged, snapshot}

      true ->
        updated_snapshot =
          snapshot
          |> DecisionSnapshot.dump()
          |> Map.put(update.constituent, update.epoch)
          |> Map.put(:policy_version, updated_policy_version)
          |> Map.put(:snapshot_seq, snapshot.snapshot_seq + 1)
          |> Map.put(:captured_at, captured_at)
          |> DecisionSnapshot.new!()

        {:updated, updated_snapshot}
    end
  end

  defp policy_version(snapshot, %KernelEpochUpdate{
         constituent: :policy_epoch,
         extensions: extensions
       }) do
    Map.get(extensions, "policy_version", snapshot.policy_version)
  end

  defp policy_version(snapshot, _update), do: snapshot.policy_version

  defp publish_read_surface(read_surface_key, read_surface_table, snapshot) do
    :persistent_term.put(read_surface_key, %{
      table: read_surface_table,
      table_key: @surface_table_key
    })

    true = :ets.insert(read_surface_table, {@surface_table_key, snapshot})
  end

  defp ensure_invariants!(
         %{read_surface_key: read_surface_key, snapshot: %DecisionSnapshot{} = snapshot} = state
       ) do
    case fetch_snapshot_by_key(read_surface_key) do
      {:ok, ^snapshot} ->
        state

      {:ok, published_snapshot} ->
        invariant_failure!(
          "read surface drifted from owner snapshot: expected=#{inspect(snapshot)} got=#{inspect(published_snapshot)}"
        )

      {:error, reason} ->
        invariant_failure!("read surface unavailable during invariant check: #{inspect(reason)}")
    end
  end

  defp fetch_snapshot(name), do: name |> read_surface_key() |> fetch_snapshot_by_key()

  defp fetch_snapshot_by_key(read_surface_key) do
    discovery = :persistent_term.get(read_surface_key, :missing)

    with {:ok, %{table: table, table_key: table_key}} <- normalize_discovery(discovery) do
      case :ets.lookup(table, table_key) do
        [{^table_key, %DecisionSnapshot{} = snapshot}] -> {:ok, snapshot}
        [] -> {:error, :snapshot_missing}
      end
    end
  rescue
    ArgumentError -> {:error, :read_surface_missing}
  end

  @spec read_surface_discovery!(term()) :: read_surface_discovery()
  defp read_surface_discovery!(name) do
    case normalize_discovery(:persistent_term.get(read_surface_key(name), :missing)) do
      {:ok, discovery} ->
        discovery

      {:error, reason} ->
        invariant_failure!("read surface discovery unavailable: #{inspect(reason)}")
    end
  end

  @spec normalize_discovery(term()) :: {:ok, read_surface_discovery()} | {:error, atom()}
  defp normalize_discovery(%{table: table, table_key: table_key})
       when is_reference(table) and table_key == @surface_table_key do
    {:ok, %{table: table, table_key: table_key}}
  end

  defp normalize_discovery(:missing), do: {:error, :read_surface_missing}
  defp normalize_discovery(_other), do: {:error, :invalid_read_surface_discovery}

  defp staleness_class(opts) do
    class = Keyword.get(opts, :staleness_class, :fresh_required)

    if class in @allowed_staleness_classes do
      {:ok, class}
    else
      {:error,
       %{
         reason: :invalid_staleness_class,
         staleness_class: class,
         safe_action: :reject_stale
       }}
    end
  end

  defp evaluate_staleness(%DecisionSnapshot{} = snapshot, :fresh_required, opts) do
    required_min_sequence = Keyword.get(opts, :required_min_sequence, snapshot.snapshot_seq)

    if snapshot.snapshot_seq >= required_min_sequence do
      {:ok, read_evidence(snapshot, :fresh_required, opts)}
    else
      {:error, stale_evidence(snapshot, :fresh_required, opts, :reject_stale)}
    end
  end

  defp evaluate_staleness(%DecisionSnapshot{} = snapshot, :bounded_stale_allowed, opts) do
    max_age_ms = Keyword.get(opts, :max_age_ms)
    max_sequence_lag = Keyword.get(opts, :max_sequence_lag)

    cond do
      not is_integer(max_age_ms) or max_age_ms < 0 ->
        {:error, missing_bound_evidence(snapshot, :bounded_stale_allowed, :max_age_ms)}

      not is_integer(max_sequence_lag) or max_sequence_lag < 0 ->
        {:error, missing_bound_evidence(snapshot, :bounded_stale_allowed, :max_sequence_lag)}

      snapshot_age_ms(snapshot) <= max_age_ms and sequence_lag(snapshot, opts) <= max_sequence_lag ->
        {:ok, read_evidence(snapshot, :bounded_stale_allowed, opts)}

      true ->
        {:error, stale_evidence(snapshot, :bounded_stale_allowed, opts, :reject_stale)}
    end
  end

  defp evaluate_staleness(%DecisionSnapshot{} = snapshot, :rebuild_required, opts) do
    {:error, stale_evidence(snapshot, :rebuild_required, opts, :rebuild_required)}
  end

  defp evaluate_staleness(%DecisionSnapshot{} = snapshot, :reject_stale, opts) do
    required_min_sequence = Keyword.get(opts, :required_min_sequence, snapshot.snapshot_seq)

    if snapshot.snapshot_seq >= required_min_sequence do
      {:ok, read_evidence(snapshot, :reject_stale, opts)}
    else
      {:error, stale_evidence(snapshot, :reject_stale, opts, :reject_stale)}
    end
  end

  defp read_evidence(%DecisionSnapshot{} = snapshot, staleness_class, opts) do
    %{
      snapshot: snapshot,
      staleness_class: staleness_class,
      snapshot_sequence: snapshot.snapshot_seq,
      required_min_sequence: Keyword.get(opts, :required_min_sequence),
      owner_sequence: owner_sequence(snapshot, opts),
      sequence_lag: sequence_lag(snapshot, opts),
      age_ms: snapshot_age_ms(snapshot),
      max_age_ms: Keyword.get(opts, :max_age_ms),
      max_sequence_lag: Keyword.get(opts, :max_sequence_lag),
      stale_read_safe_action: Keyword.get(opts, :stale_read_safe_action, :reject_stale),
      rebuild_action: Keyword.get(opts, :rebuild_action, :ask_owner_to_rebuild),
      drift: :none
    }
  end

  defp stale_evidence(%DecisionSnapshot{} = snapshot, staleness_class, opts, safe_action) do
    %{
      reason: :stale_snapshot,
      snapshot: snapshot,
      staleness_class: staleness_class,
      snapshot_sequence: snapshot.snapshot_seq,
      required_min_sequence: Keyword.get(opts, :required_min_sequence),
      owner_sequence: owner_sequence(snapshot, opts),
      sequence_lag: sequence_lag(snapshot, opts),
      age_ms: snapshot_age_ms(snapshot),
      max_age_ms: Keyword.get(opts, :max_age_ms),
      max_sequence_lag: Keyword.get(opts, :max_sequence_lag),
      safe_action: safe_action,
      rebuild_action: Keyword.get(opts, :rebuild_action, :ask_owner_to_rebuild),
      drift: :sequence_or_age
    }
  end

  defp missing_bound_evidence(%DecisionSnapshot{} = snapshot, staleness_class, missing_bound) do
    %{
      reason: :missing_staleness_bound,
      missing_bound: missing_bound,
      snapshot: snapshot,
      staleness_class: staleness_class,
      snapshot_sequence: snapshot.snapshot_seq,
      safe_action: :reject_stale,
      rebuild_action: :ask_owner_to_rebuild
    }
  end

  defp owner_sequence(%DecisionSnapshot{} = snapshot, opts) do
    Keyword.get(opts, :owner_sequence, snapshot.snapshot_seq)
  end

  defp sequence_lag(%DecisionSnapshot{} = snapshot, opts) do
    max(owner_sequence(snapshot, opts) - snapshot.snapshot_seq, 0)
  end

  defp snapshot_age_ms(%DecisionSnapshot{} = snapshot) do
    max(DateTime.diff(SystemClock.utc_now(), snapshot.captured_at, :millisecond), 0)
  end

  defp invariant_failure!(reason) do
    raise RuntimeError, "Citadel.Kernel.KernelSnapshot invariant failure: #{reason}"
  end

  defp mailbox_depth do
    case Process.info(self(), :message_queue_len) do
      {:message_queue_len, depth} -> depth
      _ -> 0
    end
  end
end
