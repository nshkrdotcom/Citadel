defmodule Citadel.Kernel.SignalIngress do
  @moduledoc """
  Always-on signal ingress root with per-session logical subscription isolation.
  """

  use GenServer

  alias Citadel.ObservabilityContract.Telemetry
  alias Citadel.Kernel.SessionDirectory
  alias Citadel.Kernel.SessionServer
  alias Citadel.Kernel.SystemClock
  alias Citadel.RuntimeObservation
  alias Citadel.SignalIngressRebuildPolicy
  alias Jido.Integration.V2.SubjectRef

  @rebuild_message :rebuild_batch
  @allowed_delivery_order_scopes [
    :partition_fifo,
    :subject_fifo,
    :boundary_session_fifo,
    :unordered_dedupe_only
  ]
  @default_admission_policy %{
    bucket_capacity: 64,
    refill_rate_per_second: 64,
    max_queue_depth_per_partition: 128,
    max_in_flight_per_tenant_scope: 512,
    retry_after_ms: 100,
    delivery_order_scope: :partition_fifo
  }

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
      admission_policy: normalize_admission_policy(Keyword.get(opts, :admission_policy, [])),
      subscriptions: %{},
      consumers: %{},
      rebuild_queue: %{},
      rebuild_scheduled?: false,
      partition_workers: %{},
      partition_worker_monitors: %{},
      partition_queue_depths: %{},
      tenant_scope_in_flight: %{},
      token_buckets: %{},
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
       tenant_scope_in_flight: state.tenant_scope_in_flight,
       token_buckets: state.token_buckets,
       admission_policy: state.admission_policy,
       partition_workers: state.partition_workers
     }, state}
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

  def handle_info(
        {:signal_delivery_finished, partition_ref, _accepted_ref, tenant_scope_key},
        state
      ) do
    {:noreply, release_admission_reservation(state, partition_ref, tenant_scope_key)}
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

  defp admit_observation(state, %RuntimeObservation{} = observation) do
    with {:ok, partition} <- partition_for_observation(observation, state.admission_policy),
         {:ok, state, bucket} <- reserve_partition_token(state, partition),
         {:ok, state} <- reserve_queue_slot(state, partition),
         {:ok, state, partition_worker} <- ensure_partition_worker(state, partition) do
      accepted_ref = accepted_ref()

      delivery = %{
        accepted_ref: accepted_ref,
        partition_ref: partition.ref,
        tenant_scope_key: partition.tenant_scope_key,
        observation: observation,
        consumer_pid: Map.get(state.consumers, observation.session_id)
      }

      state =
        state
        |> increment_tenant_scope_in_flight(partition.tenant_scope_key)
        |> update_subscription_cursor(observation)
        |> emit_signal_lag(observation)

      __MODULE__.PartitionWorker.deliver(partition_worker, delivery)

      {:ok, acceptance_evidence(accepted_ref, partition, partition_worker, bucket, state), state}
    else
      {:error, %{reason: :missing_partition_key_fields} = rejection} ->
        {:error, rejection, state}

      {:error, rejection, state} ->
        {:error, rejection, state}
    end
  end

  defp emit_signal_lag(state, observation) do
    lag_ms = DateTime.diff(state.clock.utc_now(), observation.event_at, :millisecond)

    :telemetry.execute(
      Telemetry.event_name(:signal_ingress_lag),
      %{lag_ms: max(lag_ms, 0)},
      %{source: observation.event_kind}
    )

    state
  end

  defp update_subscription_cursor(state, observation) do
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
  end

  defp partition_for_observation(%RuntimeObservation{} = observation, admission_policy) do
    tenant_id = field_value(observation, "tenant_id")
    authority_scope = field_value(observation, "authority_scope")
    boundary_session_id = field_value(observation, "boundary_session_id")
    subject_ref = observation.subject_ref

    missing_fields =
      []
      |> maybe_missing(:tenant_id, tenant_id)
      |> maybe_missing(:authority_scope, authority_scope)

    cond do
      missing_fields != [] ->
        {:error, missing_partition_fields_rejection(missing_fields, admission_policy)}

      match?(%SubjectRef{}, subject_ref) ->
        subject_ref_map = SubjectRef.dump(subject_ref)
        partition_ref = {:subject, tenant_id, authority_scope, subject_ref.ref}

        {:ok,
         %{
           ref: partition_ref,
           key: %{
             tenant_id: tenant_id,
             authority_scope: authority_scope,
             subject_ref: subject_ref_map
           },
           tenant_scope_key: {tenant_id, authority_scope},
           delivery_order_scope: admission_policy.delivery_order_scope,
           dedupe_key: {partition_ref, dedupe_component(observation)}
         }}

      present_string?(boundary_session_id) ->
        partition_ref = {:boundary_session, tenant_id, authority_scope, boundary_session_id}

        {:ok,
         %{
           ref: partition_ref,
           key: %{
             tenant_id: tenant_id,
             authority_scope: authority_scope,
             boundary_session_id: boundary_session_id
           },
           tenant_scope_key: {tenant_id, authority_scope},
           delivery_order_scope: :boundary_session_fifo,
           dedupe_key: {partition_ref, dedupe_component(observation)}
         }}

      true ->
        {:error,
         missing_partition_fields_rejection(
           [:subject_ref_or_boundary_session_id],
           admission_policy
         )}
    end
  end

  defp reserve_partition_token(state, partition) do
    tenant_scope_in_flight = Map.get(state.tenant_scope_in_flight, partition.tenant_scope_key, 0)

    if tenant_scope_in_flight >= state.admission_policy.max_in_flight_per_tenant_scope do
      queue_depth = Map.get(state.partition_queue_depths, partition.ref, 0)

      {:error,
       admission_rejection(
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
         admission_rejection(
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

  defp reserve_queue_slot(state, partition) do
    queue_depth = Map.get(state.partition_queue_depths, partition.ref, 0)
    tenant_scope_in_flight = Map.get(state.tenant_scope_in_flight, partition.tenant_scope_key, 0)

    if queue_depth >= state.admission_policy.max_queue_depth_per_partition do
      {:error,
       admission_rejection(
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
    case __MODULE__.PartitionWorker.start(
           owner: self(),
           partition_ref: partition.ref
         ) do
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

  defp acceptance_evidence(accepted_ref, partition, partition_worker, bucket, state) do
    %{
      accepted_ref: accepted_ref,
      partition_ref: partition.ref,
      partition_key: partition.key,
      tenant_scope_key: partition.tenant_scope_key,
      delivery_order_scope: partition.delivery_order_scope,
      dedupe_key: partition.dedupe_key,
      token_bucket: %{
        capacity: state.admission_policy.bucket_capacity,
        refill_rate_per_second: state.admission_policy.refill_rate_per_second,
        tokens_remaining: bucket.tokens
      },
      tenant_scope_in_flight:
        Map.get(state.tenant_scope_in_flight, partition.tenant_scope_key, 0),
      queue_depth: Map.get(state.partition_queue_depths, partition.ref, 0),
      async_handoff?: true,
      partition_worker: partition_worker
    }
  end

  defp admission_rejection(reason, partition, state, queue_depth, tenant_scope_in_flight) do
    rejection = %{
      reason: reason,
      safe_action: :retry_after,
      retry_after_ms: state.admission_policy.retry_after_ms,
      resource_exhaustion?: true,
      partition_ref: partition.ref,
      partition_key: partition.key,
      tenant_scope_key: partition.tenant_scope_key,
      delivery_order_scope: partition.delivery_order_scope,
      queue_depth_before: queue_depth,
      queue_depth_after: queue_depth,
      tenant_scope_in_flight: tenant_scope_in_flight
    }

    :telemetry.execute(
      Telemetry.event_name(:signal_ingress_admission_rejection),
      %{
        queue_depth: queue_depth,
        tenant_scope_in_flight: tenant_scope_in_flight,
        retry_after_ms: state.admission_policy.retry_after_ms
      },
      %{reason_code: reason, delivery_order_scope: partition.delivery_order_scope}
    )

    rejection
  end

  defp missing_partition_fields_rejection(missing_fields, admission_policy) do
    %{
      reason: :missing_partition_key_fields,
      missing_fields: Enum.reverse(missing_fields),
      safe_action: :reject,
      retry_after_ms: nil,
      resource_exhaustion?: false,
      delivery_order_scope: admission_policy.delivery_order_scope
    }
  end

  defp increment_tenant_scope_in_flight(state, tenant_scope_key) do
    update_in(state.tenant_scope_in_flight, fn tenant_scope_in_flight ->
      Map.update(tenant_scope_in_flight, tenant_scope_key, 1, &(&1 + 1))
    end)
  end

  defp release_admission_reservation(state, partition_ref, tenant_scope_key) do
    state
    |> update_in([:partition_queue_depths], &decrement_counter(&1, partition_ref))
    |> update_in([:tenant_scope_in_flight], &decrement_counter(&1, tenant_scope_key))
  end

  defp decrement_counter(counters, key) do
    case Map.get(counters, key, 0) do
      value when value <= 1 -> Map.delete(counters, key)
      value -> Map.put(counters, key, value - 1)
    end
  end

  defp normalize_admission_policy(opts) when is_list(opts) do
    opts
    |> Map.new()
    |> normalize_admission_policy()
  end

  defp normalize_admission_policy(opts) when is_map(opts) do
    policy = Map.merge(@default_admission_policy, opts)
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
      delivery_order_scope: delivery_order_scope
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

  defp field_value(%RuntimeObservation{} = observation, field) do
    observation.extensions
    |> Map.get(field)
    |> present_string()
    |> case do
      nil ->
        observation.payload
        |> Map.get(field)
        |> present_string()

      value ->
        value
    end
  end

  defp present_string(value) when is_binary(value) and value != "", do: value
  defp present_string(_value), do: nil

  defp present_string?(value), do: not is_nil(present_string(value))

  defp maybe_missing(missing_fields, field, value) do
    if present_string?(value), do: missing_fields, else: [field | missing_fields]
  end

  defp dedupe_component(%RuntimeObservation{} = observation) do
    field_value(observation, "idempotency_key") ||
      field_value(observation, "causation_id") ||
      observation.signal_id
  end

  defp accepted_ref do
    "signal-ingress/#{System.unique_integer([:positive, :monotonic])}"
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

defmodule Citadel.Kernel.SignalIngress.PartitionWorker do
  @moduledoc false

  use GenServer

  alias Citadel.Kernel.SessionServer

  def start(opts) do
    GenServer.start(__MODULE__, opts)
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
       partition_ref: Keyword.fetch!(opts, :partition_ref)
     }}
  end

  @impl true
  def handle_cast({:deliver, delivery}, state) do
    try do
      case delivery.consumer_pid do
        nil ->
          :ok

        pid ->
          SessionServer.record_runtime_observation(pid, delivery.observation)
      end
    catch
      :exit, {:noproc, _details} -> :ok
      :exit, :noproc -> :ok
    after
      send(
        state.owner,
        {:signal_delivery_finished, delivery.partition_ref, delivery.accepted_ref,
         delivery.tenant_scope_key}
      )
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, monitor_ref, :process, owner, _reason}, state)
      when monitor_ref == state.owner_monitor_ref and owner == state.owner do
    {:stop, :normal, state}
  end
end
