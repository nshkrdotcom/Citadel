defmodule Citadel.Kernel.SignalIngress.AdmissionGate do
  @moduledoc false

  alias Citadel.ObservabilityContract.Telemetry

  def reject_if_partition_overloaded(state, partition) do
    now_ms = System.monotonic_time(:millisecond)

    case Map.get(state.partition_overload_until_ms, partition.ref) do
      nil ->
        {:ok, state}

      overload_until_ms when overload_until_ms <= now_ms ->
        {:ok,
         update_in(state.partition_overload_until_ms, fn overloads ->
           Map.delete(overloads, partition.ref)
         end)}

      overload_until_ms ->
        queue_depth = Map.get(state.partition_queue_depths, partition.ref, 0)

        tenant_scope_in_flight =
          Map.get(state.tenant_scope_in_flight, partition.tenant_scope_key, 0)

        retry_after_ms = max(overload_until_ms - now_ms, 0)

        {:error,
         rejection(
           :partition_overloaded,
           partition,
           state,
           queue_depth,
           tenant_scope_in_flight,
           retry_after_ms
         ), state}
    end
  end

  def reserve_partition_token(state, partition) do
    tenant_scope_in_flight = Map.get(state.tenant_scope_in_flight, partition.tenant_scope_key, 0)

    if tenant_scope_in_flight >= state.admission_policy.max_in_flight_per_tenant_scope do
      queue_depth = Map.get(state.partition_queue_depths, partition.ref, 0)

      {:error,
       rejection(
         :tenant_scope_in_flight_exhausted,
         partition,
         state,
         queue_depth,
         tenant_scope_in_flight
       ), state}
    else
      {bucket, state} = refreshed_token_bucket(state, partition.ref)

      if bucket.tokens <= 0 do
        queue_depth = Map.get(state.partition_queue_depths, partition.ref, 0)

        {:error,
         rejection(
           :partition_token_exhausted,
           partition,
           state,
           queue_depth,
           tenant_scope_in_flight
         ), state}
      else
        bucket = %{bucket | tokens: bucket.tokens - 1}
        {:ok, put_in(state.token_buckets[partition.ref], bucket), bucket}
      end
    end
  end

  def reserve_queue_slot(state, partition) do
    queue_depth = Map.get(state.partition_queue_depths, partition.ref, 0)
    tenant_scope_in_flight = Map.get(state.tenant_scope_in_flight, partition.tenant_scope_key, 0)

    if queue_depth >= state.admission_policy.max_queue_depth_per_partition do
      {:error,
       rejection(
         :partition_queue_full,
         partition,
         state,
         queue_depth,
         tenant_scope_in_flight
       ), state}
    else
      {:ok,
       put_in(
         state.partition_queue_depths[partition.ref],
         queue_depth + 1
       )}
    end
  end

  def rejection(reason, partition, state, queue_depth, tenant_scope_in_flight) do
    rejection(
      reason,
      partition,
      state,
      queue_depth,
      tenant_scope_in_flight,
      state.admission_policy.retry_after_ms
    )
  end

  def rejection(reason, partition, state, queue_depth, tenant_scope_in_flight, retry_after_ms) do
    rejection = %{
      reason: reason,
      safe_action: :retry_after,
      retry_after_ms: retry_after_ms,
      resource_exhaustion?: true,
      partition_ref: partition.ref,
      partition_key: partition.key,
      tenant_scope_key: partition.tenant_scope_key,
      delivery_order_scope: partition.delivery_order_scope,
      queue_depth_before: queue_depth,
      queue_depth_after: queue_depth,
      tenant_scope_in_flight: tenant_scope_in_flight,
      overload_action: state.admission_policy.post_admission_overload_action,
      replay_action: state.admission_policy.replay_action
    }

    :telemetry.execute(
      Telemetry.event_name(:signal_ingress_admission_rejection),
      %{
        queue_depth: queue_depth,
        tenant_scope_in_flight: tenant_scope_in_flight,
        retry_after_ms: retry_after_ms
      },
      %{reason_code: reason, delivery_order_scope: partition.delivery_order_scope}
    )

    rejection
  end

  defp refreshed_token_bucket(state, partition_ref) do
    now_ms = System.monotonic_time(:millisecond)
    policy = state.admission_policy

    bucket =
      Map.get(state.token_buckets, partition_ref, %{
        tokens: policy.bucket_capacity,
        last_refill_ms: now_ms
      })

    elapsed_ms = max(now_ms - bucket.last_refill_ms, 0)
    refill_tokens = div(elapsed_ms * policy.refill_rate_per_second, 1_000)

    bucket =
      if refill_tokens > 0 do
        %{
          bucket
          | tokens: min(policy.bucket_capacity, bucket.tokens + refill_tokens),
            last_refill_ms: now_ms
        }
      else
        bucket
      end

    {bucket, put_in(state.token_buckets[partition_ref], bucket)}
  end
end
