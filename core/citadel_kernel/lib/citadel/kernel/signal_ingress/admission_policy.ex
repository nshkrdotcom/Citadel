defmodule Citadel.Kernel.SignalIngress.AdmissionPolicy do
  @moduledoc false

  @allowed_delivery_order_scopes [
    :partition_fifo,
    :subject_fifo,
    :boundary_session_fifo,
    :unordered_dedupe_only
  ]

  @default_policy %{
    bucket_capacity: 64,
    refill_rate_per_second: 64,
    max_queue_depth_per_partition: 128,
    max_in_flight_per_tenant_scope: 512,
    retry_after_ms: 100,
    delivery_order_scope: :partition_fifo,
    delivery_timeout_ms: 5_000,
    partition_overload_cooldown_ms: 1_000,
    post_admission_overload_action: :mark_partition_overloaded,
    replay_action: :replay_partition_after_retry
  }

  def normalize(opts) when is_list(opts) do
    opts
    |> Map.new()
    |> normalize()
  end

  def normalize(opts) when is_map(opts) do
    policy = Map.merge(@default_policy, opts)
    delivery_order_scope = Map.fetch!(policy, :delivery_order_scope)

    unless delivery_order_scope in @allowed_delivery_order_scopes do
      raise ArgumentError,
            "SignalIngress delivery_order_scope must be one of #{inspect(@allowed_delivery_order_scopes)}"
    end

    %{
      bucket_capacity: positive_integer!(policy.bucket_capacity, :bucket_capacity),
      refill_rate_per_second:
        non_negative_integer!(policy.refill_rate_per_second, :refill_rate_per_second),
      max_queue_depth_per_partition:
        positive_integer!(
          policy.max_queue_depth_per_partition,
          :max_queue_depth_per_partition
        ),
      max_in_flight_per_tenant_scope:
        positive_integer!(
          policy.max_in_flight_per_tenant_scope,
          :max_in_flight_per_tenant_scope
        ),
      retry_after_ms: non_negative_integer!(policy.retry_after_ms, :retry_after_ms),
      delivery_order_scope: delivery_order_scope,
      delivery_timeout_ms: positive_integer!(policy.delivery_timeout_ms, :delivery_timeout_ms),
      partition_overload_cooldown_ms:
        non_negative_integer!(
          policy.partition_overload_cooldown_ms,
          :partition_overload_cooldown_ms
        ),
      post_admission_overload_action: policy.post_admission_overload_action,
      replay_action: policy.replay_action
    }
  end

  defp positive_integer!(value, _field) when is_integer(value) and value > 0, do: value

  defp positive_integer!(value, field) do
    raise ArgumentError,
          "SignalIngress #{field} must be a positive integer, got: #{inspect(value)}"
  end

  defp non_negative_integer!(value, _field) when is_integer(value) and value >= 0, do: value

  defp non_negative_integer!(value, field) do
    raise ArgumentError,
          "SignalIngress #{field} must be a non-negative integer, got: #{inspect(value)}"
  end
end
