defmodule Citadel.Runtime.KernelSnapshot do
  @moduledoc """
  Single serialized writer for aggregate `DecisionSnapshot` publication.

  Hot-path readers use the read surface published by this owner rather than
  issuing synchronous mailbox reads on every decision pass.
  """

  use GenServer

  alias Citadel.DecisionSnapshot
  alias Citadel.KernelEpochUpdate
  alias Citadel.ObservabilityContract.Telemetry
  alias Citadel.Runtime.SystemClock

  @surface_suffix :decision_snapshot

  @type state :: %{
          clock: module(),
          read_surface_key: term(),
          snapshot: DecisionSnapshot.t()
        }

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
    :persistent_term.get(read_surface_key(name))
  end

  def read_surface_key(name \\ __MODULE__), do: {__MODULE__, name, @surface_suffix}

  @impl true
  def init(opts) do
    clock = Keyword.get(opts, :clock, SystemClock)
    name = Keyword.get(opts, :name, __MODULE__)
    read_surface_key = Keyword.get(opts, :read_surface_key, read_surface_key(name))

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

    publish_read_surface(read_surface_key, snapshot)

    {:ok,
     %{
       clock: clock,
       read_surface_key: read_surface_key,
       snapshot: snapshot
     }}
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
        publish_read_surface(state.read_surface_key, snapshot)
        {:noreply, %{state | snapshot: snapshot}}
    end
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    {:reply, state.snapshot, state}
  end

  defp apply_update(%DecisionSnapshot{} = snapshot, %KernelEpochUpdate{} = update, captured_at) do
    current_epoch = Map.fetch!(snapshot, update.constituent)
    updated_policy_version = policy_version(snapshot, update)

    if current_epoch == update.epoch and updated_policy_version == snapshot.policy_version do
      {:unchanged, snapshot}
    else
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

  defp publish_read_surface(read_surface_key, snapshot) do
    :persistent_term.put(read_surface_key, snapshot)
  end

  defp mailbox_depth do
    case Process.info(self(), :message_queue_len) do
      {:message_queue_len, depth} -> depth
      _ -> 0
    end
  end
end
