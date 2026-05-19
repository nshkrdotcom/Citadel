defmodule Citadel.Kernel.SignalIngress.SubscriptionRegistry do
  @moduledoc false

  alias Citadel.Kernel.SignalIngress.PartitionRouter
  alias Citadel.RuntimeObservation

  def subscription(session_id, opts, now) do
    priority_class = Keyword.get(opts, :priority_class, "background")

    %{
      session_id: session_id,
      subscription_ref: Keyword.get(opts, :subscription_ref, "subscription/#{session_id}"),
      committed_signal_cursor: Keyword.get(opts, :committed_signal_cursor),
      transport_cursor: Keyword.get(opts, :transport_cursor),
      status: Keyword.get(opts, :status, :active),
      priority_class: priority_class,
      registered_at: now,
      last_seen_at: now,
      tenant_scope_key: tenant_scope_from_opts(opts),
      rebuilt_at: now,
      extensions: Keyword.get(opts, :extensions, %{})
    }
  end

  def put_subscription(state, session_id, subscription) do
    %{state | subscriptions: Map.put(state.subscriptions, session_id, subscription)}
  end

  def unregister(state, session_id) do
    %{
      state
      | subscriptions: Map.delete(state.subscriptions, session_id),
        consumers: Map.delete(state.consumers, session_id),
        consumer_last_seen_at: Map.delete(state.consumer_last_seen_at, session_id)
    }
  end

  def register_consumer(state, session_id, pid, now) when is_pid(pid) do
    %{
      state
      | consumers: Map.put(state.consumers, session_id, pid),
        consumer_last_seen_at: Map.put(state.consumer_last_seen_at, session_id, now)
    }
  end

  def update_cursor(state, %RuntimeObservation{} = observation, source_anchor, now) do
    update_in(state.subscriptions, fn subscriptions ->
      case Map.get(subscriptions, observation.session_id) do
        nil ->
          subscriptions

        subscription ->
          Map.put(subscriptions, observation.session_id, %{
            subscription
            | transport_cursor: observation.signal_cursor || subscription.transport_cursor,
              extensions:
                PartitionRouter.remember_source_anchor(subscription.extensions, source_anchor),
              last_seen_at: now
          })
      end
    end)
  end

  def touch_consumer(state, session_id, now) do
    if Map.has_key?(state.consumers, session_id) do
      %{
        state
        | consumer_last_seen_at: Map.put(state.consumer_last_seen_at, session_id, now)
      }
    else
      state
    end
  end

  def tenant_scope_from_opts(opts) do
    Keyword.get(opts, :tenant_scope_key) ||
      case {Keyword.get(opts, :tenant_id), Keyword.get(opts, :authority_scope)} do
        {tenant_id, authority_scope} when is_binary(tenant_id) and is_binary(authority_scope) ->
          {tenant_id, authority_scope}

        _other ->
          :default
      end
  end
end
