defmodule Citadel.Kernel.SignalIngress.PartitionWorker do
  @moduledoc false

  use GenServer

  alias Citadel.ObservabilityContract.Telemetry
  alias Citadel.Kernel.SessionServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def deliver(worker, delivery) when is_pid(worker) do
    GenServer.cast(worker, {:deliver, delivery})
  end

  @impl true
  def init(opts) do
    owner = Keyword.fetch!(opts, :owner)

    {:ok,
     %{
       owner: owner,
       owner_monitor_ref: Process.monitor(owner),
       partition_ref: Keyword.fetch!(opts, :partition_ref),
       overloaded_until_ms: nil
     }}
  end

  @impl true
  def handle_cast({:deliver, delivery}, state) do
    {delivery_result, state} = deliver_with_overload_boundary(delivery, state)

    send(
      state.owner,
      {:signal_delivery_finished, delivery.partition_ref, delivery.accepted_ref,
       delivery.tenant_scope_key, delivery_result}
    )

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, monitor_ref, :process, owner, _reason}, state)
      when monitor_ref == state.owner_monitor_ref and owner == state.owner do
    {:stop, :normal, state}
  end

  defp deliver_with_overload_boundary(delivery, state) do
    now_ms = System.monotonic_time(:millisecond)

    if is_integer(state.overloaded_until_ms) and state.overloaded_until_ms > now_ms do
      retry_after_ms = state.overloaded_until_ms - now_ms

      result =
        delivery_result(
          delivery,
          :deferred_for_replay,
          :partition_overloaded,
          0,
          retry_after_ms
        )

      emit_delivery_overload(result)
      {result, state}
    else
      deliver_to_consumer(delivery, state)
    end
  end

  defp deliver_to_consumer(delivery, state) do
    started_at = System.monotonic_time(:millisecond)

    try do
      case delivery.consumer_pid do
        nil ->
          :ok

        pid ->
          SessionServer.record_runtime_observation(
            pid,
            delivery.observation,
            timeout: delivery.delivery_timeout_ms
          )
      end

      {delivery_result(delivery, :delivered, :none, elapsed_ms(started_at), 0), state}
    catch
      :exit, {:timeout, _details} ->
        timeout_result(delivery, state, started_at, :consumer_timeout)

      :exit, :timeout ->
        timeout_result(delivery, state, started_at, :consumer_timeout)

      :exit, {:noproc, _details} ->
        {delivery_result(delivery, :consumer_unavailable, :noproc, elapsed_ms(started_at), 0),
         state}

      :exit, :noproc ->
        {delivery_result(delivery, :consumer_unavailable, :noproc, elapsed_ms(started_at), 0),
         state}
    end
  end

  defp timeout_result(delivery, state, started_at, reason) do
    retry_after_ms = delivery.overload_cooldown_ms

    result =
      delivery_result(
        delivery,
        :timed_out,
        reason,
        elapsed_ms(started_at),
        retry_after_ms
      )

    emit_delivery_overload(result)

    {result,
     %{
       state
       | overloaded_until_ms: System.monotonic_time(:millisecond) + retry_after_ms
     }}
  end

  defp delivery_result(delivery, status, reason, duration_ms, retry_after_ms) do
    %{
      delivery_status: status,
      reason: reason,
      duration_ms: max(duration_ms, 0),
      retry_after_ms: retry_after_ms,
      delivery_order_scope: delivery.delivery_order_scope,
      overload_action: delivery.overload_action,
      replay_action: delivery.replay_action
    }
  end

  defp emit_delivery_overload(result) do
    :telemetry.execute(
      Telemetry.event_name(:signal_ingress_delivery_overload),
      %{duration_ms: result.duration_ms, retry_after_ms: result.retry_after_ms},
      %{
        reason_code: result.reason,
        delivery_order_scope: result.delivery_order_scope,
        replay_action: result.replay_action
      }
    )
  end

  defp elapsed_ms(started_at) do
    System.monotonic_time(:millisecond) - started_at
  end
end
