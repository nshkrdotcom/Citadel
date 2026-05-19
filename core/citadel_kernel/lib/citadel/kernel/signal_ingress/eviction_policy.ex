defmodule Citadel.Kernel.SignalIngress.EvictionPolicy do
  @moduledoc false

  @default_policy %{
    sweep_interval_ms: 60_000,
    max_evictions_per_sweep: 128,
    subscription_ttl_ms: 15 * 60_000,
    consumer_ttl_ms: 15 * 60_000,
    rebuild_queue_ttl_ms: 15 * 60_000,
    partition_state_ttl_ms: 15 * 60_000,
    max_subscriptions_total: 100_000,
    max_subscriptions_per_tenant: 25_000,
    max_consumers_total: 100_000,
    max_rebuild_queue_total: 100_000,
    max_partitions_total: 50_000
  }

  def normalize(opts) when is_list(opts) do
    opts
    |> Map.new()
    |> normalize()
  end

  def normalize(opts) when is_map(opts) do
    policy = Map.merge(@default_policy, opts)

    %{
      sweep_interval_ms: non_negative_integer!(policy.sweep_interval_ms, :sweep_interval_ms),
      max_evictions_per_sweep:
        positive_integer!(policy.max_evictions_per_sweep, :max_evictions_per_sweep),
      subscription_ttl_ms:
        non_negative_integer!(policy.subscription_ttl_ms, :subscription_ttl_ms),
      consumer_ttl_ms: non_negative_integer!(policy.consumer_ttl_ms, :consumer_ttl_ms),
      rebuild_queue_ttl_ms:
        non_negative_integer!(policy.rebuild_queue_ttl_ms, :rebuild_queue_ttl_ms),
      partition_state_ttl_ms:
        non_negative_integer!(policy.partition_state_ttl_ms, :partition_state_ttl_ms),
      max_subscriptions_total:
        positive_integer!(policy.max_subscriptions_total, :max_subscriptions_total),
      max_subscriptions_per_tenant:
        positive_integer!(
          policy.max_subscriptions_per_tenant,
          :max_subscriptions_per_tenant
        ),
      max_consumers_total: positive_integer!(policy.max_consumers_total, :max_consumers_total),
      max_rebuild_queue_total:
        positive_integer!(policy.max_rebuild_queue_total, :max_rebuild_queue_total),
      max_partitions_total: positive_integer!(policy.max_partitions_total, :max_partitions_total)
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
