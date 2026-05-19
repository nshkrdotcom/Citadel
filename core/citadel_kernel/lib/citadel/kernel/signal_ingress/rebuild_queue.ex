defmodule Citadel.Kernel.SignalIngress.RebuildQueue do
  @moduledoc false

  alias Citadel.ObservabilityContract.Telemetry
  alias Citadel.Kernel.SessionDirectory
  alias Citadel.SignalIngressRebuildPolicy

  def active_sessions(session_directory) do
    session_directory
    |> SessionDirectory.list_active_session_cursors()
    |> Map.new(fn cursor_info -> {cursor_info.session_id, cursor_info} end)
  end

  def enqueue(state, active_sessions) do
    %{state | rebuild_queue: Map.merge(state.rebuild_queue, active_sessions)}
  end

  def load_committed_cursors(session_directory, batch) do
    SessionDirectory.batch_load_committed_cursors(session_directory, Map.keys(batch))
  end

  def merge_subscriptions(cursor_map, subscriptions, rebuilt_at) do
    Enum.reduce(cursor_map, subscriptions, fn {session_id, cursor_info}, subscriptions ->
      Map.put(subscriptions, session_id, %{
        session_id: session_id,
        subscription_ref: "subscription/#{session_id}",
        committed_signal_cursor: cursor_info.committed_signal_cursor,
        transport_cursor: cursor_info.committed_signal_cursor,
        status: :rebuilt,
        priority_class: cursor_info.priority_class,
        registered_at: cursor_info.registered_at,
        rebuilt_at: rebuilt_at,
        extensions: %{}
      })
    end)
  end

  def take_batch(rebuild_queue, %SignalIngressRebuildPolicy{} = rebuild_policy) do
    rebuild_queue
    |> Enum.sort_by(fn {_session_id, cursor_info} ->
      {SignalIngressRebuildPolicy.priority_rank(rebuild_policy, cursor_info.priority_class),
       cursor_info.registered_at}
    end)
    |> Enum.split(rebuild_policy.max_sessions_per_batch)
    |> then(fn {selected, remaining} -> {Map.new(selected), Map.new(remaining)} end)
  end

  def group_for_transport(cursor_map, partition_fun) do
    cursor_map
    |> Map.values()
    |> Enum.group_by(partition_fun)
  end

  def batch_priority_class(batch, %SignalIngressRebuildPolicy{} = rebuild_policy) do
    batch
    |> Map.values()
    |> Enum.min_by(
      &SignalIngressRebuildPolicy.priority_rank(rebuild_policy, &1.priority_class),
      fn -> %{priority_class: "background"} end
    )
    |> Map.get(:priority_class)
  end

  def emit_backlog_telemetry(rebuild_queue) do
    rebuild_queue
    |> Map.values()
    |> Enum.group_by(& &1.priority_class)
    |> Enum.each(fn {priority_class, entries} ->
      :telemetry.execute(
        Telemetry.event_name(:signal_ingress_rebuild_backlog),
        %{count: length(entries)},
        %{priority_class: priority_class}
      )
    end)
  end
end
