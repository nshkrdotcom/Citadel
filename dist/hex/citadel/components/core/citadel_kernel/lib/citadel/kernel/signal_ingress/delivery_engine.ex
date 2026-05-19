defmodule Citadel.Kernel.SignalIngress.DeliveryEngine do
  @moduledoc false

  alias Citadel.ObservabilityContract.Telemetry
  alias Citadel.RuntimeObservation

  def accepted_ref do
    "signal-ingress/#{System.unique_integer([:positive, :monotonic])}"
  end

  def increment_tenant_scope_in_flight(state, tenant_scope_key) do
    update_in(state.tenant_scope_in_flight, fn tenant_scope_in_flight ->
      Map.update(tenant_scope_in_flight, tenant_scope_key, 1, &(&1 + 1))
    end)
  end

  def release_admission_reservation(state, partition_ref, tenant_scope_key) do
    state
    |> update_in([:partition_queue_depths], &decrement_counter(&1, partition_ref))
    |> update_in([:tenant_scope_in_flight], &decrement_counter(&1, tenant_scope_key))
    |> touch_partition(partition_ref)
  end

  def maybe_mark_partition_overloaded(state, partition_ref, %{
        delivery_status: delivery_status,
        retry_after_ms: retry_after_ms
      })
      when delivery_status in [:timed_out, :deferred_for_replay] do
    overload_until_ms = System.monotonic_time(:millisecond) + retry_after_ms

    update_in(state.partition_overload_until_ms, fn overloads ->
      Map.put(overloads, partition_ref, overload_until_ms)
    end)
  end

  def maybe_mark_partition_overloaded(state, _partition_ref, _delivery_result), do: state

  def touch_partition(state, partition_ref) do
    put_in(state.partition_last_seen_at_ms[partition_ref], System.monotonic_time(:millisecond))
  end

  def emit_signal_lag(state, %RuntimeObservation{} = observation) do
    lag_ms = DateTime.diff(state.clock.utc_now(), observation.event_at, :millisecond)

    :telemetry.execute(
      Telemetry.event_name(:signal_ingress_lag),
      %{lag_ms: max(lag_ms, 0)},
      %{source: observation.event_kind}
    )

    state
  end

  def acceptance_evidence(accepted_ref, partition, partition_worker, bucket, state) do
    %{
      accepted_ref: accepted_ref,
      partition_ref: partition.ref,
      partition_key: partition.key,
      tenant_scope_key: partition.tenant_scope_key,
      delivery_order_scope: partition.delivery_order_scope,
      dedupe_key: partition.dedupe_key,
      lineage: partition.lineage,
      token_bucket: %{
        capacity: state.admission_policy.bucket_capacity,
        refill_rate_per_second: state.admission_policy.refill_rate_per_second,
        tokens_remaining: bucket.tokens
      },
      tenant_scope_in_flight:
        Map.get(state.tenant_scope_in_flight, partition.tenant_scope_key, 0),
      queue_depth: Map.get(state.partition_queue_depths, partition.ref, 0),
      delivery_timeout_ms: state.admission_policy.delivery_timeout_ms,
      partition_overload_cooldown_ms: state.admission_policy.partition_overload_cooldown_ms,
      overload_action: state.admission_policy.post_admission_overload_action,
      replay_action: state.admission_policy.replay_action,
      async_handoff?: true,
      partition_worker: partition_worker
    }
  end

  defp decrement_counter(counters, key) do
    case Map.get(counters, key, 0) do
      value when value <= 1 -> Map.delete(counters, key)
      value -> Map.put(counters, key, value - 1)
    end
  end
end
