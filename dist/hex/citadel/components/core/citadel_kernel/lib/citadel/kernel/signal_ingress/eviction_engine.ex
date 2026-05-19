defmodule Citadel.Kernel.SignalIngress.EvictionEngine do
  @moduledoc false

  def prepare_subscription_capacity(state, session_id, tenant_scope_key) do
    state =
      state
      |> sweep_expired_consumers(:sweep)
      |> elem(0)
      |> sweep_expired_subscriptions(:sweep)
      |> elem(0)

    with {:ok, state} <- ensure_subscription_total_capacity(state, session_id),
         {:ok, state} <- ensure_subscription_tenant_capacity(state, session_id, tenant_scope_key) do
      {:ok, state}
    end
  end

  def prepare_consumer_capacity(state, session_id) do
    state = sweep_expired_consumers(state, :sweep) |> elem(0)

    if Map.has_key?(state.consumers, session_id) or
         map_size(state.consumers) < state.eviction_policy.max_consumers_total do
      {:ok, state}
    else
      state = evict_dead_consumers(state, 1)

      if map_size(state.consumers) < state.eviction_policy.max_consumers_total do
        {:ok, state}
      else
        {:error,
         capacity_rejection(
           :consumer_capacity_exhausted,
           :consumers,
           map_size(state.consumers),
           state.eviction_policy.max_consumers_total
         ), state}
      end
    end
  end

  def prepare_rebuild_queue_capacity(state, active_sessions) do
    state = sweep_expired_rebuild_queue(state, :sweep) |> elem(0)

    projected_size = rebuild_queue_projected_size(state.rebuild_queue, active_sessions)

    if projected_size <= state.eviction_policy.max_rebuild_queue_total do
      {:ok, state}
    else
      {state, _count} = sweep_expired_rebuild_queue(state, :capacity)
      projected_size = rebuild_queue_projected_size(state.rebuild_queue, active_sessions)

      if projected_size <= state.eviction_policy.max_rebuild_queue_total do
        {:ok, state}
      else
        {:error,
         capacity_rejection(
           :rebuild_queue_capacity_exhausted,
           :rebuild_queue,
           projected_size,
           state.eviction_policy.max_rebuild_queue_total
         ), state}
      end
    end
  end

  def sweep_expired_state(state) do
    {state, consumers} = sweep_expired_consumers(state, :sweep)
    {state, subscriptions} = sweep_expired_subscriptions(state, :sweep)
    {state, rebuild_queue} = sweep_expired_rebuild_queue(state, :sweep)
    {state, partitions} = sweep_expired_partitions(state, :sweep)

    {state,
     %{
       subscriptions: subscriptions,
       consumers: consumers,
       rebuild_queue: rebuild_queue,
       partitions: partitions
     }}
  end

  def sweep_expired_partitions(state, mode) do
    candidates =
      state
      |> idle_partition_candidates()
      |> Enum.filter(fn {_partition_ref, last_seen_ms} ->
        mode == :capacity or partition_ttl_expired?(state, last_seen_ms)
      end)
      |> Enum.sort_by(fn {_partition_ref, last_seen_ms} -> last_seen_ms end)

    evict_count = bounded_evict_count(state, candidates, mode)

    state =
      candidates
      |> Enum.take(evict_count)
      |> Enum.reduce(state, fn {partition_ref, _last_seen_ms}, state ->
        evict_partition_state(state, partition_ref)
      end)

    {state, evict_count}
  end

  def known_partition?(state, partition_ref) do
    Map.has_key?(state.partition_workers, partition_ref) or
      Map.has_key?(state.token_buckets, partition_ref) or
      Map.has_key?(state.partition_queue_depths, partition_ref) or
      Map.has_key?(state.partition_overload_until_ms, partition_ref) or
      Map.has_key?(state.partition_last_seen_at_ms, partition_ref)
  end

  def partition_count(state), do: state |> partition_refs() |> length()

  defp ensure_subscription_total_capacity(state, session_id) do
    if Map.has_key?(state.subscriptions, session_id) or
         map_size(state.subscriptions) < state.eviction_policy.max_subscriptions_total do
      {:ok, state}
    else
      state =
        evict_subscription_candidates(
          state,
          inactive_subscription_candidates(state),
          1,
          :capacity
        )

      if map_size(state.subscriptions) < state.eviction_policy.max_subscriptions_total do
        {:ok, state}
      else
        {:error,
         capacity_rejection(
           :subscription_capacity_exhausted,
           :subscriptions,
           map_size(state.subscriptions),
           state.eviction_policy.max_subscriptions_total
         ), state}
      end
    end
  end

  defp ensure_subscription_tenant_capacity(state, session_id, tenant_scope_key) do
    if Map.has_key?(state.subscriptions, session_id) do
      {:ok, state}
    else
      count =
        state.subscriptions
        |> Map.values()
        |> Enum.count(&(Map.get(&1, :tenant_scope_key, :default) == tenant_scope_key))

      if count < state.eviction_policy.max_subscriptions_per_tenant do
        {:ok, state}
      else
        candidates =
          state
          |> inactive_subscription_candidates()
          |> Enum.filter(fn {_session_id, subscription} ->
            Map.get(subscription, :tenant_scope_key, :default) == tenant_scope_key
          end)

        state = evict_subscription_candidates(state, candidates, 1, :capacity)

        updated_count =
          state.subscriptions
          |> Map.values()
          |> Enum.count(&(Map.get(&1, :tenant_scope_key, :default) == tenant_scope_key))

        if updated_count < state.eviction_policy.max_subscriptions_per_tenant do
          {:ok, state}
        else
          {:error,
           capacity_rejection(
             :subscription_tenant_capacity_exhausted,
             :subscriptions,
             updated_count,
             state.eviction_policy.max_subscriptions_per_tenant
           ), state}
        end
      end
    end
  end

  defp rebuild_queue_projected_size(rebuild_queue, active_sessions) do
    new_session_count =
      MapSet.size(
        MapSet.difference(
          MapSet.new(Map.keys(active_sessions)),
          MapSet.new(Map.keys(rebuild_queue))
        )
      )

    map_size(rebuild_queue) + new_session_count
  end

  defp sweep_expired_subscriptions(state, mode) do
    candidates =
      state
      |> inactive_subscription_candidates()
      |> Enum.filter(fn {_session_id, subscription} ->
        ttl_expired?(Map.get(subscription, :last_seen_at) || subscription.registered_at, state)
      end)

    evict_count = bounded_evict_count(state, candidates, mode)
    state = evict_subscription_candidates(state, candidates, evict_count, mode)
    {state, evict_count}
  end

  defp inactive_subscription_candidates(state) do
    state.subscriptions
    |> Enum.reject(fn {session_id, _subscription} ->
      Map.has_key?(state.consumers, session_id) or Map.has_key?(state.rebuild_queue, session_id)
    end)
    |> Enum.sort_by(fn {_session_id, subscription} ->
      Map.get(subscription, :last_seen_at) || subscription.registered_at
    end)
  end

  defp evict_subscription_candidates(state, candidates, count, _mode) do
    session_ids =
      candidates
      |> Enum.take(count)
      |> Enum.map(fn {session_id, _subscription} -> session_id end)

    %{
      state
      | subscriptions: Map.drop(state.subscriptions, session_ids),
        consumers: Map.drop(state.consumers, session_ids),
        consumer_last_seen_at: Map.drop(state.consumer_last_seen_at, session_ids)
    }
  end

  defp sweep_expired_consumers(state, mode) do
    candidates =
      state.consumers
      |> Enum.filter(fn {session_id, pid} ->
        consumer_expired?(state, session_id, pid)
      end)
      |> Enum.sort_by(fn {session_id, _pid} ->
        Map.get(state.consumer_last_seen_at, session_id, state.restarted_at)
      end)

    evict_count = bounded_evict_count(state, candidates, mode)
    state = evict_consumers(state, candidates, evict_count)
    {state, evict_count}
  end

  defp evict_dead_consumers(state, count) do
    candidates =
      state.consumers
      |> Enum.filter(fn {_session_id, pid} -> not Process.alive?(pid) end)
      |> Enum.sort_by(fn {session_id, _pid} ->
        Map.get(state.consumer_last_seen_at, session_id, state.restarted_at)
      end)

    evict_consumers(state, candidates, count)
  end

  defp evict_consumers(state, candidates, count) do
    session_ids =
      candidates
      |> Enum.take(count)
      |> Enum.map(fn {session_id, _pid} -> session_id end)

    %{
      state
      | consumers: Map.drop(state.consumers, session_ids),
        consumer_last_seen_at: Map.drop(state.consumer_last_seen_at, session_ids)
    }
  end

  defp consumer_expired?(state, session_id, pid) do
    last_seen_at = Map.get(state.consumer_last_seen_at, session_id, state.restarted_at)
    not Process.alive?(pid) and ttl_expired?(last_seen_at, state, :consumer_ttl_ms)
  end

  defp sweep_expired_rebuild_queue(state, mode) do
    candidates =
      state.rebuild_queue
      |> Enum.filter(fn {_session_id, cursor_info} ->
        ttl_expired?(cursor_info.registered_at, state, :rebuild_queue_ttl_ms)
      end)
      |> Enum.sort_by(fn {_session_id, cursor_info} -> cursor_info.registered_at end)

    evict_count = bounded_evict_count(state, candidates, mode)

    session_ids =
      candidates
      |> Enum.take(evict_count)
      |> Enum.map(fn {session_id, _cursor_info} -> session_id end)

    {%{state | rebuild_queue: Map.drop(state.rebuild_queue, session_ids)}, evict_count}
  end

  defp idle_partition_candidates(state) do
    state
    |> partition_refs()
    |> Enum.filter(fn partition_ref ->
      Map.get(state.partition_queue_depths, partition_ref, 0) == 0 and
        not Map.has_key?(state.partition_overload_until_ms, partition_ref)
    end)
    |> Enum.map(fn partition_ref ->
      {partition_ref, Map.get(state.partition_last_seen_at_ms, partition_ref, 0)}
    end)
  end

  defp evict_partition_state(state, partition_ref) do
    state =
      case Map.get(state.partition_workers, partition_ref) do
        pid when is_pid(pid) ->
          Process.exit(pid, :shutdown)
          %{state | partition_workers: Map.delete(state.partition_workers, partition_ref)}

        _missing ->
          state
      end

    monitor_refs =
      state.partition_worker_monitors
      |> Enum.filter(fn {_monitor_ref, ref} -> ref == partition_ref end)
      |> Enum.map(fn {monitor_ref, _ref} -> monitor_ref end)

    Enum.each(monitor_refs, &Process.demonitor(&1, [:flush]))

    %{
      state
      | partition_worker_monitors: Map.drop(state.partition_worker_monitors, monitor_refs),
        partition_queue_depths: Map.delete(state.partition_queue_depths, partition_ref),
        partition_overload_until_ms: Map.delete(state.partition_overload_until_ms, partition_ref),
        partition_last_seen_at_ms: Map.delete(state.partition_last_seen_at_ms, partition_ref),
        token_buckets: Map.delete(state.token_buckets, partition_ref)
    }
  end

  defp partition_refs(state) do
    [
      Map.keys(state.partition_workers),
      Map.keys(state.token_buckets),
      Map.keys(state.partition_queue_depths),
      Map.keys(state.partition_overload_until_ms),
      Map.keys(state.partition_last_seen_at_ms)
    ]
    |> List.flatten()
    |> Enum.uniq()
  end

  defp bounded_evict_count(state, candidates, :capacity) do
    min(length(candidates), state.eviction_policy.max_evictions_per_sweep)
  end

  defp bounded_evict_count(state, candidates, :sweep) do
    min(length(candidates), state.eviction_policy.max_evictions_per_sweep)
  end

  defp ttl_expired?(nil, _state), do: false
  defp ttl_expired?(timestamp, state), do: ttl_expired?(timestamp, state, :subscription_ttl_ms)

  defp ttl_expired?(%DateTime{} = timestamp, state, field) do
    DateTime.diff(state.clock.utc_now(), timestamp, :millisecond) >=
      Map.fetch!(state.eviction_policy, field)
  end

  defp ttl_expired?(_timestamp, _state, _field), do: false

  defp partition_ttl_expired?(state, last_seen_ms) do
    System.monotonic_time(:millisecond) - last_seen_ms >=
      state.eviction_policy.partition_state_ttl_ms
  end

  defp capacity_rejection(reason, segment, count, ceiling) do
    %{
      reason: reason,
      safe_action: :retry_after,
      retry_after_ms: 100,
      resource_exhaustion?: true,
      segment: segment,
      count: count,
      ceiling: ceiling
    }
  end
end
