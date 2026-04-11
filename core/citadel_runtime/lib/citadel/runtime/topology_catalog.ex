defmodule Citadel.Runtime.TopologyCatalog do
  @moduledoc """
  Host-local topology defaults and routing-constraint owner.
  """

  use GenServer

  alias Citadel.KernelEpochUpdate
  alias Citadel.Runtime.KernelSnapshot
  alias Citadel.Runtime.SystemClock

  @flush_message :flush_epoch_update

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def snapshot(server \\ __MODULE__) do
    GenServer.call(server, :snapshot)
  end

  def update_topology(server \\ __MODULE__, topology_state) do
    GenServer.call(server, {:update_topology, topology_state})
  end

  @impl true
  def init(opts) do
    {:ok,
     %{
       kernel_snapshot: Keyword.get(opts, :kernel_snapshot, KernelSnapshot),
       clock: Keyword.get(opts, :clock, SystemClock),
       flush_interval_ms: Keyword.get(opts, :flush_interval_ms, 10),
       topology_state: Keyword.get(opts, :topology_state, %{}),
       topology_epoch: Keyword.get(opts, :topology_epoch, 0),
       pending_epoch: nil,
       pending_updated_at: nil,
       flush_timer_ref: nil
     }}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    {:reply, %{topology_state: state.topology_state, topology_epoch: state.topology_epoch}, state}
  end

  def handle_call({:update_topology, topology_state}, _from, state) do
    if state.topology_state == topology_state do
      {:reply, {:ok, state.topology_epoch}, state}
    else
      updated_at = state.clock.utc_now()

      state =
        state
        |> Map.put(:topology_state, topology_state)
        |> Map.put(:topology_epoch, state.topology_epoch + 1)
        |> Map.put(:pending_epoch, state.topology_epoch + 1)
        |> Map.put(:pending_updated_at, updated_at)
        |> schedule_flush()

      {:reply, {:ok, state.topology_epoch}, state}
    end
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
        constituent: :topology_epoch,
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

  defp schedule_flush(%{flush_timer_ref: nil, flush_interval_ms: interval_ms} = state) do
    %{state | flush_timer_ref: Process.send_after(self(), @flush_message, interval_ms)}
  end

  defp schedule_flush(state), do: state
end
