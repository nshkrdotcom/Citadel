defmodule Citadel.Runtime.PolicyCache do
  @moduledoc """
  Host-local mutable policy snapshot owner.
  """

  use GenServer

  alias Citadel.KernelEpochUpdate
  alias Citadel.ObservabilityContract.Telemetry
  alias Citadel.Runtime.KernelSnapshot
  alias Citadel.Runtime.SystemClock

  @flush_message :flush_epoch_update

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def peek(server \\ __MODULE__) do
    started_at = System.monotonic_time(:millisecond)
    policy = GenServer.call(server, :peek)
    duration_ms = System.monotonic_time(:millisecond) - started_at

    :telemetry.execute(
      Telemetry.event_name(:policy_peek_latency),
      %{duration_ms: max(duration_ms, 0)},
      %{}
    )

    policy
  end

  def update_policy(server \\ __MODULE__, policy_version, policy_snapshot) do
    GenServer.call(server, {:update_policy, policy_version, policy_snapshot})
  end

  def epoch(server \\ __MODULE__) do
    GenServer.call(server, :epoch)
  end

  @impl true
  def init(opts) do
    {:ok,
     %{
       kernel_snapshot: Keyword.get(opts, :kernel_snapshot, KernelSnapshot),
       clock: Keyword.get(opts, :clock, SystemClock),
       flush_interval_ms: Keyword.get(opts, :flush_interval_ms, 10),
       policy_snapshot: Keyword.get(opts, :policy_snapshot, %{}),
       policy_version: Keyword.get(opts, :policy_version, "policy/uninitialized"),
       policy_epoch: Keyword.get(opts, :policy_epoch, 0),
       pending_epoch: nil,
       pending_policy_version: nil,
       pending_updated_at: nil,
       flush_timer_ref: nil
     }}
  end

  @impl true
  def handle_call(:peek, _from, state) do
    {:reply, %{policy_version: state.policy_version, policy_snapshot: state.policy_snapshot, policy_epoch: state.policy_epoch}, state}
  end

  def handle_call(:epoch, _from, state) do
    {:reply, state.policy_epoch, state}
  end

  def handle_call({:update_policy, policy_version, policy_snapshot}, _from, state) do
    if state.policy_version == policy_version and state.policy_snapshot == policy_snapshot do
      {:reply, {:ok, state.policy_epoch}, state}
    else
      updated_at = state.clock.utc_now()

      state =
        state
        |> Map.put(:policy_version, policy_version)
        |> Map.put(:policy_snapshot, policy_snapshot)
        |> Map.put(:policy_epoch, state.policy_epoch + 1)
        |> Map.put(:pending_epoch, state.policy_epoch + 1)
        |> Map.put(:pending_policy_version, policy_version)
        |> Map.put(:pending_updated_at, updated_at)
        |> schedule_flush()

      {:reply, {:ok, state.policy_epoch}, state}
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
        constituent: :policy_epoch,
        epoch: state.pending_epoch,
        updated_at: state.pending_updated_at,
        extensions: %{"policy_version" => state.pending_policy_version}
      })
    )

    {:noreply,
     %{
       state
       | pending_epoch: nil,
         pending_policy_version: nil,
         pending_updated_at: nil,
         flush_timer_ref: nil
     }}
  end

  defp schedule_flush(%{flush_timer_ref: nil, flush_interval_ms: interval_ms} = state) do
    %{state | flush_timer_ref: Process.send_after(self(), @flush_message, interval_ms)}
  end

  defp schedule_flush(state), do: state
end
