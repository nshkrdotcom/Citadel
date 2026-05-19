defmodule Citadel.Kernel.SignalIngress do
  @moduledoc """
  Always-on signal ingress root with per-session logical subscription isolation.
  """

  use GenServer

  alias Citadel.ObservabilityContract.Telemetry
  alias Citadel.Kernel.SessionDirectory
  alias Citadel.Kernel.SignalIngress.AdmissionGate
  alias Citadel.Kernel.SignalIngress.AdmissionPolicy
  alias Citadel.Kernel.SignalIngress.DeliveryEngine
  alias Citadel.Kernel.SignalIngress.EvictionEngine
  alias Citadel.Kernel.SignalIngress.EvictionPolicy
  alias Citadel.Kernel.SignalIngress.PartitionRouter
  alias Citadel.Kernel.SignalIngress.RebuildQueue
  alias Citadel.Kernel.SignalIngress.SubscriptionRegistry
  alias Citadel.Kernel.SystemClock
  alias Citadel.RuntimeObservation
  alias Citadel.SignalIngressRebuildPolicy

  @rebuild_message :rebuild_batch
  @eviction_sweep_message :eviction_sweep

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

  defp default_partition_supervisor! do
    supervisor = Citadel.Kernel.SignalIngress.PartitionSupervisor

    case Process.whereis(supervisor) do
      pid when is_pid(pid) ->
        supervisor

      nil ->
        raise ArgumentError,
              "Citadel.Kernel.SignalIngress requires a supervised :partition_worker_supervisor " <>
                "or a running #{inspect(supervisor)}"
    end
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

  def sweep_expired(server \\ __MODULE__) do
    GenServer.call(server, :sweep_expired)
  end

  @impl true
  def init(opts) do
    state =
      %{
        session_directory: Keyword.get(opts, :session_directory, SessionDirectory),
        signal_source: Keyword.fetch!(opts, :signal_source),
        clock: Keyword.get(opts, :clock, SystemClock),
        rebuild_policy: Keyword.get(opts, :rebuild_policy, SignalIngressRebuildPolicy.new!(%{})),
        transport_partition_fun:
          Keyword.get(opts, :transport_partition_fun, fn _cursor_info -> :default end),
        transport_reposition_fun:
          Keyword.get(opts, :transport_reposition_fun, fn _groups -> :ok end),
        admission_policy: AdmissionPolicy.normalize(Keyword.get(opts, :admission_policy, [])),
        eviction_policy: EvictionPolicy.normalize(Keyword.get(opts, :eviction_policy, [])),
        subscriptions: %{},
        consumers: %{},
        consumer_last_seen_at: %{},
        rebuild_queue: %{},
        rebuild_scheduled?: false,
        partition_workers: %{},
        partition_worker_monitors: %{},
        partition_worker_supervisor:
          Keyword.get(
            opts,
            :partition_worker_supervisor,
            Citadel.Kernel.SignalIngress.PartitionSupervisor
          ),
        partition_queue_depths: %{},
        partition_overload_until_ms: %{},
        partition_last_seen_at_ms: %{},
        tenant_scope_in_flight: %{},
        token_buckets: %{},
        sweep_timer_ref: nil,
        restarted_at: Keyword.get(opts, :restarted_at, SystemClock.utc_now())
      }
      |> schedule_eviction_sweep()

    if Keyword.get(opts, :auto_rebuild?, false) do
      send(self(), @rebuild_message)
      {:ok, %{state | rebuild_scheduled?: true}}
    else
      {:ok, state}
    end
  end

  @impl true
  def handle_call({:register_subscription, session_id, opts}, _from, state) do
    subscription = SubscriptionRegistry.subscription(session_id, opts, state.clock.utc_now())

    case EvictionEngine.prepare_subscription_capacity(
           state,
           session_id,
           subscription.tenant_scope_key
         ) do
      {:ok, state} ->
        state =
          state
          |> SubscriptionRegistry.put_subscription(session_id, subscription)
          |> maybe_emit_high_priority_ready_latency(
            subscription.priority_class,
            subscription.registered_at
          )

        {:reply, :ok, state}

      {:error, rejection, state} ->
        {:reply, {:error, rejection}, state}
    end
  end

  def handle_call({:unregister_subscription, session_id}, _from, state) do
    {:reply, :ok, SubscriptionRegistry.unregister(state, session_id)}
  end

  def handle_call({:register_consumer, session_id, pid}, _from, state) do
    case EvictionEngine.prepare_consumer_capacity(state, session_id) do
      {:ok, state} ->
        {:reply, :ok,
         SubscriptionRegistry.register_consumer(state, session_id, pid, state.clock.utc_now())}

      {:error, rejection, state} ->
        {:reply, {:error, rejection}, state}
    end
  end

  def handle_call(:rebuild_from_directory, _from, state) do
    active_sessions = RebuildQueue.active_sessions(state.session_directory)

    case EvictionEngine.prepare_rebuild_queue_capacity(state, active_sessions) do
      {:ok, state} ->
        state =
          state
          |> RebuildQueue.enqueue(active_sessions)
          |> schedule_rebuild()

        RebuildQueue.emit_backlog_telemetry(state.rebuild_queue)
        {:reply, :ok, state}

      {:error, rejection, state} ->
        {:reply, {:error, rejection}, state}
    end
  end

  def handle_call({:deliver_signal, raw_signal}, _from, state) do
    case state.signal_source.normalize_signal(raw_signal) do
      {:ok, observation} ->
        case admit_observation(state, observation) do
          {:ok, acceptance, state} -> {:reply, {:ok, acceptance}, state}
          {:error, rejection, state} -> {:reply, {:error, rejection}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:subscription_state, session_id}, _from, state) do
    {:reply, Map.get(state.subscriptions, session_id), state}
  end

  def handle_call(:snapshot, _from, state) do
    {:reply,
     %{
       subscriptions: state.subscriptions,
       rebuild_queue: state.rebuild_queue,
       partition_queue_depths: state.partition_queue_depths,
       partition_overload_until_ms: state.partition_overload_until_ms,
       partition_last_seen_at_ms: state.partition_last_seen_at_ms,
       tenant_scope_in_flight: state.tenant_scope_in_flight,
       token_buckets: state.token_buckets,
       admission_policy: state.admission_policy,
       eviction_policy: state.eviction_policy,
       consumers: state.consumers,
       consumer_last_seen_at: state.consumer_last_seen_at,
       partition_workers: state.partition_workers
     }, state}
  end

  def handle_call(:sweep_expired, _from, state) do
    {state, summary} = EvictionEngine.sweep_expired_state(state)
    {:reply, summary, state}
  end

  @impl true
  def handle_info(@rebuild_message, state) do
    if map_size(state.rebuild_queue) == 0 do
      {:noreply, %{state | rebuild_scheduled?: false}}
    else
      {batch, remaining_queue} =
        RebuildQueue.take_batch(state.rebuild_queue, state.rebuild_policy)

      started_at = System.monotonic_time(:millisecond)

      cursor_map =
        RebuildQueue.load_committed_cursors(state.session_directory, batch)

      grouped = RebuildQueue.group_for_transport(cursor_map, state.transport_partition_fun)
      _ = state.transport_reposition_fun.(grouped)

      subscriptions =
        RebuildQueue.merge_subscriptions(cursor_map, state.subscriptions, state.clock.utc_now())

      duration_ms = System.monotonic_time(:millisecond) - started_at
      priority_class = RebuildQueue.batch_priority_class(batch, state.rebuild_policy)

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

      RebuildQueue.emit_backlog_telemetry(remaining_queue)

      if map_size(remaining_queue) > 0 do
        Process.send_after(self(), @rebuild_message, state.rebuild_policy.batch_interval_ms)
      end

      {:noreply, state}
    end
  end

  def handle_info(
        {:signal_delivery_finished, partition_ref, _accepted_ref, tenant_scope_key,
         delivery_result},
        state
      ) do
    state =
      state
      |> DeliveryEngine.release_admission_reservation(partition_ref, tenant_scope_key)
      |> DeliveryEngine.maybe_mark_partition_overloaded(partition_ref, delivery_result)

    {:noreply, state}
  end

  def handle_info({:DOWN, monitor_ref, :process, _pid, _reason}, state) do
    case Map.pop(state.partition_worker_monitors, monitor_ref) do
      {nil, _worker_monitors} ->
        {:noreply, state}

      {partition_ref, worker_monitors} ->
        {:noreply,
         %{
           state
           | partition_workers: Map.delete(state.partition_workers, partition_ref),
             partition_worker_monitors: worker_monitors
         }}
    end
  end

  def handle_info(@eviction_sweep_message, state) do
    {state, _summary} = EvictionEngine.sweep_expired_state(state)
    {:noreply, schedule_eviction_sweep(%{state | sweep_timer_ref: nil})}
  end

  defp admit_observation(state, %RuntimeObservation{} = observation) do
    with {:ok, partition} <-
           PartitionRouter.route(state.subscriptions, observation, state.admission_policy),
         {:ok, state} <- AdmissionGate.reject_if_partition_overloaded(state, partition),
         {:ok, state} <- ensure_partition_capacity(state, partition),
         {:ok, state, bucket} <- AdmissionGate.reserve_partition_token(state, partition),
         {:ok, state} <- AdmissionGate.reserve_queue_slot(state, partition),
         {:ok, state, partition_worker} <- ensure_partition_worker(state, partition) do
      accepted_ref = DeliveryEngine.accepted_ref()

      delivery = %{
        accepted_ref: accepted_ref,
        partition_ref: partition.ref,
        tenant_scope_key: partition.tenant_scope_key,
        observation: observation,
        consumer_pid: Map.get(state.consumers, observation.session_id),
        delivery_order_scope: partition.delivery_order_scope,
        delivery_timeout_ms: state.admission_policy.delivery_timeout_ms,
        overload_cooldown_ms: state.admission_policy.partition_overload_cooldown_ms,
        overload_action: state.admission_policy.post_admission_overload_action,
        replay_action: state.admission_policy.replay_action
      }

      state =
        state
        |> DeliveryEngine.increment_tenant_scope_in_flight(partition.tenant_scope_key)
        |> SubscriptionRegistry.update_cursor(
          observation,
          partition.lineage.source_anchor,
          state.clock.utc_now()
        )
        |> SubscriptionRegistry.touch_consumer(observation.session_id, state.clock.utc_now())
        |> DeliveryEngine.touch_partition(partition.ref)
        |> DeliveryEngine.emit_signal_lag(observation)

      __MODULE__.PartitionWorker.deliver(partition_worker, delivery)

      {:ok,
       DeliveryEngine.acceptance_evidence(
         accepted_ref,
         partition,
         partition_worker,
         bucket,
         state
       ), state}
    else
      {:error, %{reason: :missing_partition_key_fields} = rejection} ->
        {:error, rejection, state}

      {:error, %{reason: :missing_lineage_fields} = rejection} ->
        {:error, rejection, state}

      {:error, %{reason: :regressed_source_position_or_revision} = rejection} ->
        {:error, rejection, state}

      {:error, rejection, state} ->
        {:error, rejection, state}
    end
  end

  defp ensure_partition_capacity(state, partition) do
    if EvictionEngine.known_partition?(state, partition.ref) or
         EvictionEngine.partition_count(state) < state.eviction_policy.max_partitions_total do
      {:ok, state}
    else
      {state, _summary} = EvictionEngine.sweep_expired_partitions(state, :capacity)

      if EvictionEngine.partition_count(state) < state.eviction_policy.max_partitions_total do
        {:ok, state}
      else
        queue_depth = Map.get(state.partition_queue_depths, partition.ref, 0)

        tenant_scope_in_flight =
          Map.get(state.tenant_scope_in_flight, partition.tenant_scope_key, 0)

        {:error,
         AdmissionGate.rejection(
           :partition_capacity_exhausted,
           partition,
           state,
           queue_depth,
           tenant_scope_in_flight
         ), state}
      end
    end
  end

  defp ensure_partition_worker(state, partition) do
    case Map.get(state.partition_workers, partition.ref) do
      pid when is_pid(pid) ->
        if Process.alive?(pid) do
          {:ok, state, pid}
        else
          start_partition_worker(
            %{state | partition_workers: Map.delete(state.partition_workers, partition.ref)},
            partition
          )
        end

      _missing ->
        start_partition_worker(state, partition)
    end
  end

  defp start_partition_worker(state, partition) do
    child_spec =
      {__MODULE__.PartitionWorker, owner: self(), partition_ref: partition.ref}

    case start_partition_child(state.partition_worker_supervisor, child_spec) do
      {:ok, pid} ->
        monitor_ref = Process.monitor(pid)

        {:ok,
         %{
           state
           | partition_workers: Map.put(state.partition_workers, partition.ref, pid),
             partition_worker_monitors:
               Map.put(state.partition_worker_monitors, monitor_ref, partition.ref)
         }, pid}

      {:error, reason} ->
        {:error,
         %{
           reason: :partition_worker_unavailable,
           details: reason,
           partition_key: partition.key,
           safe_action: :retry_after,
           retry_after_ms: state.admission_policy.retry_after_ms,
           resource_exhaustion?: true
         }, state}
    end
  end

  defp start_partition_child(supervisor, child_spec) do
    supervisor = ensure_partition_supervisor!(supervisor)

    DynamicSupervisor.start_child(supervisor, child_spec)
  catch
    :exit, reason -> {:error, reason}
  end

  defp ensure_partition_supervisor!(Citadel.Kernel.SignalIngress.PartitionSupervisor) do
    default_partition_supervisor!()
  end

  defp ensure_partition_supervisor!(supervisor) do
    supervisor
  end

  defp schedule_rebuild(%{rebuild_scheduled?: true} = state), do: state

  defp schedule_rebuild(state) do
    Process.send_after(self(), @rebuild_message, 0)
    %{state | rebuild_scheduled?: true}
  end

  defp schedule_eviction_sweep(state) do
    if state.eviction_policy.sweep_interval_ms > 0 do
      %{
        state
        | sweep_timer_ref:
            Process.send_after(
              self(),
              @eviction_sweep_message,
              state.eviction_policy.sweep_interval_ms
            )
      }
    else
      state
    end
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
end
