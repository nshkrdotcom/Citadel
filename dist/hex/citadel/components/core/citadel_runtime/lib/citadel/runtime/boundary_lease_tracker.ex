defmodule Citadel.Runtime.BoundaryLeaseTracker do
  @moduledoc """
  Host-local boundary liveness and targeted resume-classification owner.
  """

  use GenServer

  alias Citadel.BoundaryLeaseView
  alias Citadel.BoundaryResumePolicy
  alias Citadel.KernelEpochUpdate
  alias Citadel.ObservabilityContract.Telemetry
  alias Citadel.Runtime.KernelSnapshot
  alias Citadel.Runtime.SystemClock

  @flush_message :flush_boundary_epoch

  @type bootstrap_result ::
          {:ok, BoundaryLeaseView.t()}
          | {:error, :not_ready | :resume_pending | :missing | :expired | :circuit_open | atom()}

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def record_boundary_view(server \\ __MODULE__, %BoundaryLeaseView{} = boundary_lease_view) do
    GenServer.call(server, {:record_boundary_view, boundary_lease_view})
  end

  def current_view(server \\ __MODULE__, boundary_ref) do
    GenServer.call(server, {:current_view, boundary_ref})
  end

  def classify_for_resume(server \\ __MODULE__, boundary_ref) do
    GenServer.call(server, {:classify_for_resume, boundary_ref}, :infinity)
  end

  def boundary_epoch(server \\ __MODULE__) do
    GenServer.call(server, :boundary_epoch)
  end

  def warm?(server \\ __MODULE__) do
    GenServer.call(server, :warm?)
  end

  def set_warm(server \\ __MODULE__, warm?) do
    GenServer.call(server, {:set_warm, warm?})
  end

  def set_circuit_open(server \\ __MODULE__, key, open?) do
    GenServer.call(server, {:set_circuit_open, key, open?})
  end

  @impl true
  def init(opts) do
    {:ok,
     %{
       kernel_snapshot: Keyword.get(opts, :kernel_snapshot, KernelSnapshot),
       clock: Keyword.get(opts, :clock, SystemClock),
       flush_interval_ms: Keyword.get(opts, :flush_interval_ms, 10),
       boundary_epoch: Keyword.get(opts, :boundary_epoch, 0),
       pending_epoch: nil,
       pending_updated_at: nil,
       flush_timer_ref: nil,
       leases: %{},
       warm?: Keyword.get(opts, :warm?, false),
       resume_policy: Keyword.get(opts, :resume_policy, BoundaryResumePolicy.new!(%{})),
       bootstrap_fun: Keyword.get(opts, :bootstrap_fun, fn _boundary_ref -> {:error, :not_ready} end),
       classification_key_fun: Keyword.get(opts, :classification_key_fun, fn _boundary_ref -> nil end),
       inflight: %{},
       circuit_open_keys: MapSet.new()
     }}
  end

  @impl true
  def handle_call({:record_boundary_view, %BoundaryLeaseView{} = boundary_lease_view}, _from, state) do
    state = update_lease(state, boundary_lease_view)
    {:reply, {:ok, state.boundary_epoch}, state}
  end

  def handle_call({:current_view, boundary_ref}, _from, state) do
    {:reply, Map.get(state.leases, boundary_ref), state}
  end

  def handle_call({:classify_for_resume, boundary_ref}, from, state) do
    case Map.get(state.leases, boundary_ref) do
      %BoundaryLeaseView{} = boundary_lease_view ->
        {:reply, {:ok, boundary_lease_view}, state}

      nil ->
        coalesce_key = coalesce_key(state, boundary_ref)

        cond do
          circuit_open?(state, coalesce_key) ->
            emit_circuit_open_telemetry()
            {:reply, {:error, :circuit_open}, state}

          Map.has_key?(state.inflight, coalesce_key) ->
            inflight_entry = Map.fetch!(state.inflight, coalesce_key)

            inflight =
              Map.put(state.inflight, coalesce_key, %{
                inflight_entry
                | waiters: [from | inflight_entry.waiters],
                  coalesced_request_count: inflight_entry.coalesced_request_count + 1
              })

            emit_bootstrap_backlog_telemetry(inflight)
            {:noreply, %{state | inflight: inflight}}

          true ->
            state = start_bootstrap_attempt(state, coalesce_key, boundary_ref, from)
            {:noreply, state}
        end
    end
  end

  def handle_call(:boundary_epoch, _from, state) do
    {:reply, state.boundary_epoch, state}
  end

  def handle_call(:warm?, _from, state) do
    {:reply, state.warm?, state}
  end

  def handle_call({:set_warm, warm?}, _from, state) do
    {:reply, :ok, %{state | warm?: warm?}}
  end

  def handle_call({:set_circuit_open, key, true}, _from, state) do
    {:reply, :ok, %{state | circuit_open_keys: MapSet.put(state.circuit_open_keys, key)}}
  end

  def handle_call({:set_circuit_open, key, false}, _from, state) do
    {:reply, :ok, %{state | circuit_open_keys: MapSet.delete(state.circuit_open_keys, key)}}
  end

  @impl true
  def handle_info(@flush_message, %{pending_epoch: nil} = state) do
    {:noreply, %{state | flush_timer_ref: nil}}
  end

  def handle_info(@flush_message, state) do
    KernelSnapshot.publish_epoch_update(
      state.kernel_snapshot,
      KernelEpochUpdate.new!(%{
        source_owner: Atom.to_string(__MODULE__),
        constituent: :boundary_epoch,
        epoch: state.pending_epoch,
        updated_at: state.pending_updated_at,
        extensions: %{}
      })
    )

    {:noreply,
     %{
       state
       | pending_epoch: nil,
         pending_updated_at: nil,
         flush_timer_ref: nil
     }}
  end

  def handle_info({:bootstrap_result, coalesce_key, boundary_ref, result}, state) do
    case Map.get(state.inflight, coalesce_key) do
      nil ->
        {:noreply, state}

      inflight_entry ->
        cancel_timer_if_any(inflight_entry.ttl_timer_ref)

        case result do
          {:ok, %BoundaryLeaseView{} = boundary_lease_view} ->
            Enum.each(inflight_entry.waiters, &GenServer.reply(&1, {:ok, boundary_lease_view}))

            state =
              state
              |> update_lease(boundary_lease_view)
              |> clear_inflight(coalesce_key)

            emit_bootstrap_backlog_telemetry(state.inflight)
            {:noreply, state}

          {:error, reason} when reason in [:not_ready, :resume_pending] ->
            maybe_retry_bootstrap(state, coalesce_key, inflight_entry, boundary_ref)

          {:error, :circuit_open} ->
            Enum.each(inflight_entry.waiters, &GenServer.reply(&1, {:error, :circuit_open}))
            emit_circuit_open_telemetry()
            state = clear_inflight(state, coalesce_key)
            {:noreply, state}

          {:error, reason} ->
            Enum.each(inflight_entry.waiters, &GenServer.reply(&1, {:error, reason}))
            state = clear_inflight(state, coalesce_key)
            {:noreply, state}
        end
    end
  end

  def handle_info({:retry_bootstrap, coalesce_key}, state) do
    case Map.get(state.inflight, coalesce_key) do
      nil ->
        {:noreply, state}

      inflight_entry ->
        if circuit_open?(state, coalesce_key) do
          Enum.each(inflight_entry.waiters, &GenServer.reply(&1, {:error, :circuit_open}))
          emit_circuit_open_telemetry()
          state = clear_inflight(state, coalesce_key)
          {:noreply, state}
        else
          state = launch_bootstrap_task(state, coalesce_key, inflight_entry.boundary_ref, inflight_entry)
          {:noreply, state}
        end
    end
  end

  def handle_info({:bootstrap_ttl_expired, coalesce_key}, state) do
    case Map.get(state.inflight, coalesce_key) do
      nil ->
        {:noreply, state}

      inflight_entry ->
        Enum.each(inflight_entry.waiters, &GenServer.reply(&1, {:error, :bootstrap_timeout}))
        state = clear_inflight(state, coalesce_key)
        emit_bootstrap_backlog_telemetry(state.inflight)
        {:noreply, state}
    end
  end

  defp start_bootstrap_attempt(state, coalesce_key, boundary_ref, from) do
    inflight_entry = %{
      boundary_ref: boundary_ref,
      first_requested_at: state.clock.utc_now(),
      waiters: [from],
      coalesced_request_count: 0,
      ttl_timer_ref: nil,
      retry_timer_ref: nil
    }

    state = put_inflight(state, coalesce_key, inflight_entry)
    state = launch_bootstrap_task(state, coalesce_key, boundary_ref, Map.fetch!(state.inflight, coalesce_key))
    emit_bootstrap_backlog_telemetry(state.inflight)
    state
  end

  defp launch_bootstrap_task(state, coalesce_key, boundary_ref, inflight_entry) do
    owner = self()

    ttl_timer_ref =
      Process.send_after(
        self(),
        {:bootstrap_ttl_expired, coalesce_key},
        state.resume_policy.coalesced_request_ttl_ms
      )

    Task.start(fn ->
      send(owner, {:bootstrap_result, coalesce_key, boundary_ref, state.bootstrap_fun.(boundary_ref)})
    end)

    put_inflight(state, coalesce_key, %{inflight_entry | ttl_timer_ref: ttl_timer_ref, retry_timer_ref: nil})
  end

  defp maybe_retry_bootstrap(state, coalesce_key, inflight_entry, boundary_ref) do
    waited_ms = DateTime.diff(state.clock.utc_now(), inflight_entry.first_requested_at, :millisecond)

    if waited_ms + state.resume_policy.retry_interval_ms > state.resume_policy.max_wait_ms do
      Enum.each(inflight_entry.waiters, &GenServer.reply(&1, {:error, :resume_wait_exhausted}))
      state = clear_inflight(state, coalesce_key)
      {:noreply, state}
    else
      retry_timer_ref =
        Process.send_after(self(), {:retry_bootstrap, coalesce_key}, state.resume_policy.retry_interval_ms)

      updated_inflight_entry = %{
        inflight_entry
        | boundary_ref: boundary_ref,
          retry_timer_ref: retry_timer_ref,
          ttl_timer_ref: nil
      }

      state = put_inflight(state, coalesce_key, updated_inflight_entry)
      emit_bootstrap_backlog_telemetry(state.inflight)
      {:noreply, state}
    end
  end

  defp update_lease(state, %BoundaryLeaseView{} = boundary_lease_view) do
    previous = Map.get(state.leases, boundary_lease_view.boundary_ref)

    if decision_relevant_boundary_view(previous) == decision_relevant_boundary_view(boundary_lease_view) do
      %{state | leases: Map.put(state.leases, boundary_lease_view.boundary_ref, boundary_lease_view)}
    else
      updated_at = state.clock.utc_now()

      state
      |> Map.put(:leases, Map.put(state.leases, boundary_lease_view.boundary_ref, boundary_lease_view))
      |> Map.put(:boundary_epoch, state.boundary_epoch + 1)
      |> Map.put(:pending_epoch, state.boundary_epoch + 1)
      |> Map.put(:pending_updated_at, updated_at)
      |> schedule_flush()
    end
  end

  defp decision_relevant_boundary_view(nil), do: nil

  defp decision_relevant_boundary_view(%BoundaryLeaseView{} = boundary_lease_view) do
    {boundary_lease_view.boundary_ref, boundary_lease_view.staleness_status, boundary_lease_view.expires_at}
  end

  defp put_inflight(state, coalesce_key, inflight_entry) do
    %{state | inflight: Map.put(state.inflight, coalesce_key, inflight_entry)}
  end

  defp clear_inflight(state, coalesce_key) do
    case Map.get(state.inflight, coalesce_key) do
      nil ->
        %{state | inflight: Map.delete(state.inflight, coalesce_key)}

      inflight_entry ->
        cancel_timer_if_any(inflight_entry.ttl_timer_ref)
        cancel_timer_if_any(inflight_entry.retry_timer_ref)
        %{state | inflight: Map.delete(state.inflight, coalesce_key)}
    end
  end

  defp coalesce_key(state, boundary_ref) do
    case state.classification_key_fun.(boundary_ref) do
      nil -> boundary_ref
      key -> key
    end
  end

  defp circuit_open?(state, key) do
    MapSet.member?(state.circuit_open_keys, key)
  end

  defp emit_circuit_open_telemetry do
    :telemetry.execute(
      Telemetry.event_name(:bridge_circuit_open),
      %{count: 1},
      %{bridge_family: :boundary, circuit_scope_class: :targeted_resume_bootstrap}
    )
  end

  defp emit_bootstrap_backlog_telemetry(inflight) do
    coalesced_request_count =
      inflight
      |> Map.values()
      |> Enum.map(& &1.coalesced_request_count)
      |> Enum.sum()

    :telemetry.execute(
      Telemetry.event_name(:boundary_bootstrap_backlog),
      %{count: map_size(inflight), coalesced_request_count: coalesced_request_count},
      %{}
    )
  end

  defp schedule_flush(%{flush_timer_ref: nil} = state) do
    %{state | flush_timer_ref: Process.send_after(self(), @flush_message, state.flush_interval_ms)}
  end

  defp schedule_flush(state), do: state

  defp cancel_timer_if_any(nil), do: :ok
  defp cancel_timer_if_any(timer_ref), do: Process.cancel_timer(timer_ref)
end
