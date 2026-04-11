defmodule Citadel.Runtime.SignalIngress do
  @moduledoc """
  Always-on signal ingress root with per-session logical subscription isolation.
  """

  use GenServer

  alias Citadel.ObservabilityContract.Telemetry
  alias Citadel.Runtime.SessionDirectory
  alias Citadel.Runtime.SessionServer
  alias Citadel.Runtime.SystemClock
  alias Citadel.RuntimeObservation
  alias Citadel.SignalIngressRebuildPolicy

  @rebuild_message :rebuild_batch

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def register_subscription(server \\ __MODULE__, session_id, opts \\ []) do
    GenServer.call(server, {:register_subscription, session_id, opts})
  end

  def unregister_subscription(server \\ __MODULE__, session_id) do
    GenServer.call(server, {:unregister_subscription, session_id})
  end

  def register_consumer(server \\ __MODULE__, session_id, pid) when is_pid(pid) do
    GenServer.call(server, {:register_consumer, session_id, pid})
  end

  def rebuild_from_directory(server \\ __MODULE__) do
    GenServer.call(server, :rebuild_from_directory)
  end

  def deliver_signal(server \\ __MODULE__, raw_signal) do
    GenServer.call(server, {:deliver_signal, raw_signal})
  end

  def deliver_observation(server \\ __MODULE__, %RuntimeObservation{} = observation) do
    deliver_signal(server, observation)
  end

  def subscription_state(server \\ __MODULE__, session_id) do
    GenServer.call(server, {:subscription_state, session_id})
  end

  def snapshot(server \\ __MODULE__) do
    GenServer.call(server, :snapshot)
  end

  @impl true
  def init(opts) do
    state = %{
      session_directory: Keyword.get(opts, :session_directory, SessionDirectory),
      signal_source: Keyword.fetch!(opts, :signal_source),
      clock: Keyword.get(opts, :clock, SystemClock),
      rebuild_policy: Keyword.get(opts, :rebuild_policy, SignalIngressRebuildPolicy.new!(%{})),
      transport_partition_fun:
        Keyword.get(opts, :transport_partition_fun, fn _cursor_info -> :default end),
      transport_reposition_fun:
        Keyword.get(opts, :transport_reposition_fun, fn _groups -> :ok end),
      subscriptions: %{},
      consumers: %{},
      rebuild_queue: %{},
      rebuild_scheduled?: false,
      restarted_at: Keyword.get(opts, :restarted_at, SystemClock.utc_now())
    }

    if Keyword.get(opts, :auto_rebuild?, false) do
      send(self(), @rebuild_message)
      {:ok, %{state | rebuild_scheduled?: true}}
    else
      {:ok, state}
    end
  end

  @impl true
  def handle_call({:register_subscription, session_id, opts}, _from, state) do
    priority_class = Keyword.get(opts, :priority_class, "background")
    committed_signal_cursor = Keyword.get(opts, :committed_signal_cursor)

    subscription = %{
      session_id: session_id,
      subscription_ref: Keyword.get(opts, :subscription_ref, "subscription/#{session_id}"),
      committed_signal_cursor: committed_signal_cursor,
      transport_cursor: Keyword.get(opts, :transport_cursor),
      status: Keyword.get(opts, :status, :active),
      priority_class: priority_class,
      registered_at: state.clock.utc_now(),
      rebuilt_at: state.clock.utc_now(),
      extensions: Keyword.get(opts, :extensions, %{})
    }

    state =
      state
      |> put_subscription(session_id, subscription)
      |> maybe_emit_high_priority_ready_latency(priority_class, subscription.registered_at)

    {:reply, :ok, state}
  end

  def handle_call({:unregister_subscription, session_id}, _from, state) do
    {:reply, :ok,
     %{
       state
       | subscriptions: Map.delete(state.subscriptions, session_id),
         consumers: Map.delete(state.consumers, session_id)
     }}
  end

  def handle_call({:register_consumer, session_id, pid}, _from, state) do
    {:reply, :ok, %{state | consumers: Map.put(state.consumers, session_id, pid)}}
  end

  def handle_call(:rebuild_from_directory, _from, state) do
    active_sessions =
      state.session_directory
      |> SessionDirectory.list_active_session_cursors()
      |> Map.new(fn cursor_info -> {cursor_info.session_id, cursor_info} end)

    state =
      state
      |> Map.put(:rebuild_queue, Map.merge(state.rebuild_queue, active_sessions))
      |> schedule_rebuild()

    emit_rebuild_backlog_telemetry(state.rebuild_queue)
    {:reply, :ok, state}
  end

  def handle_call({:deliver_signal, raw_signal}, _from, state) do
    case state.signal_source.normalize_signal(raw_signal) do
      {:ok, observation} ->
        state = route_observation(state, observation)
        {:reply, :ok, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:subscription_state, session_id}, _from, state) do
    {:reply, Map.get(state.subscriptions, session_id), state}
  end

  def handle_call(:snapshot, _from, state) do
    {:reply, %{subscriptions: state.subscriptions, rebuild_queue: state.rebuild_queue}, state}
  end

  @impl true
  def handle_info(@rebuild_message, state) do
    if map_size(state.rebuild_queue) == 0 do
      {:noreply, %{state | rebuild_scheduled?: false}}
    else
      {batch, remaining_queue} = take_rebuild_batch(state.rebuild_queue, state.rebuild_policy)
      started_at = System.monotonic_time(:millisecond)

      cursor_map =
        SessionDirectory.batch_load_committed_cursors(state.session_directory, Map.keys(batch))

      grouped = group_for_transport(cursor_map, state.transport_partition_fun)
      _ = state.transport_reposition_fun.(grouped)

      subscriptions =
        Enum.reduce(cursor_map, state.subscriptions, fn {session_id, cursor_info},
                                                        subscriptions ->
          Map.put(subscriptions, session_id, %{
            session_id: session_id,
            subscription_ref: "subscription/#{session_id}",
            committed_signal_cursor: cursor_info.committed_signal_cursor,
            transport_cursor: cursor_info.committed_signal_cursor,
            status: :rebuilt,
            priority_class: cursor_info.priority_class,
            registered_at: cursor_info.registered_at,
            rebuilt_at: state.clock.utc_now(),
            extensions: %{}
          })
        end)

      duration_ms = System.monotonic_time(:millisecond) - started_at
      priority_class = batch_priority_class(batch, state.rebuild_policy)

      :telemetry.execute(
        Telemetry.event_name(:signal_ingress_rebuild_batch_latency),
        %{duration_ms: max(duration_ms, 0)},
        %{priority_class: priority_class}
      )

      Enum.each(cursor_map, fn {_session_id, cursor_info} ->
        maybe_emit_high_priority_ready_latency(
          state,
          cursor_info.priority_class,
          cursor_info.registered_at
        )
      end)

      state =
        state
        |> Map.put(:subscriptions, subscriptions)
        |> Map.put(:rebuild_queue, remaining_queue)
        |> Map.put(:rebuild_scheduled?, map_size(remaining_queue) > 0)

      emit_rebuild_backlog_telemetry(remaining_queue)

      if map_size(remaining_queue) > 0 do
        Process.send_after(self(), @rebuild_message, state.rebuild_policy.batch_interval_ms)
      end

      {:noreply, state}
    end
  end

  defp route_observation(state, observation) do
    lag_ms = DateTime.diff(state.clock.utc_now(), observation.event_at, :millisecond)

    :telemetry.execute(
      Telemetry.event_name(:signal_ingress_lag),
      %{lag_ms: max(lag_ms, 0)},
      %{source: observation.event_kind}
    )

    state =
      update_in(state.subscriptions, fn subscriptions ->
        case Map.get(subscriptions, observation.session_id) do
          nil ->
            subscriptions

          subscription ->
            Map.put(subscriptions, observation.session_id, %{
              subscription
              | transport_cursor: observation.signal_cursor || subscription.transport_cursor
            })
        end
      end)

    case Map.get(state.consumers, observation.session_id) do
      nil ->
        state

      pid ->
        _ =
          try do
            SessionServer.record_runtime_observation(pid, observation)
          catch
            :exit, {:noproc, _details} -> :ok
            :exit, :noproc -> :ok
          end

        state
    end
  end

  defp schedule_rebuild(%{rebuild_scheduled?: true} = state), do: state

  defp schedule_rebuild(state) do
    Process.send_after(self(), @rebuild_message, 0)
    %{state | rebuild_scheduled?: true}
  end

  defp take_rebuild_batch(rebuild_queue, %SignalIngressRebuildPolicy{} = rebuild_policy) do
    rebuild_queue
    |> Enum.sort_by(fn {_session_id, cursor_info} ->
      {SignalIngressRebuildPolicy.priority_rank(rebuild_policy, cursor_info.priority_class),
       cursor_info.registered_at}
    end)
    |> Enum.split(rebuild_policy.max_sessions_per_batch)
    |> then(fn {selected, remaining} -> {Map.new(selected), Map.new(remaining)} end)
  end

  defp group_for_transport(cursor_map, partition_fun) do
    cursor_map
    |> Map.values()
    |> Enum.group_by(partition_fun)
  end

  defp batch_priority_class(batch, %SignalIngressRebuildPolicy{} = rebuild_policy) do
    batch
    |> Map.values()
    |> Enum.min_by(
      &SignalIngressRebuildPolicy.priority_rank(rebuild_policy, &1.priority_class),
      fn -> %{priority_class: "background"} end
    )
    |> Map.get(:priority_class)
  end

  defp emit_rebuild_backlog_telemetry(rebuild_queue) do
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

  defp maybe_emit_high_priority_ready_latency(state, priority_class, registered_at) do
    if priority_class in ["explicit_resume", "live_request", "pending_replay_safe"] do
      duration_ms =
        DateTime.diff(state.clock.utc_now(), registered_at || state.restarted_at, :millisecond)

      :telemetry.execute(
        Telemetry.event_name(:signal_ingress_high_priority_ready_latency),
        %{duration_ms: max(duration_ms, 0)},
        %{}
      )
    end

    state
  end

  defp put_subscription(state, session_id, subscription) do
    %{state | subscriptions: Map.put(state.subscriptions, session_id, subscription)}
  end
end
