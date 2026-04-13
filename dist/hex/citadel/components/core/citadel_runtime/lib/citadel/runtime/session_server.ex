defmodule Citadel.Runtime.SessionServer do
  @moduledoc """
  Dynamic owner for one session's mutable host-local runtime state.
  """

  use GenServer

  alias Citadel.ActionOutboxEntry
  alias Citadel.BackoffPolicy
  alias Citadel.DecisionRejection
  alias Citadel.LocalAction
  alias Citadel.ObservabilityContract.Telemetry
  alias Citadel.ObservabilityContract.Trace
  alias Citadel.PersistedSessionBlob
  alias Citadel.PersistedSessionEnvelope
  alias Citadel.RuntimeObservation
  alias Citadel.Runtime.BoundaryLeaseTracker
  alias Citadel.Runtime.KernelSnapshot
  alias Citadel.Runtime.ServiceCatalog
  alias Citadel.Runtime.SessionDirectory
  alias Citadel.Runtime.SignalIngress
  alias Citadel.Runtime.Staleness
  alias Citadel.Runtime.SystemClock
  alias Citadel.SessionContinuityCommit
  alias Citadel.SessionOutbox
  alias Citadel.SessionState
  alias Citadel.ServiceDescriptor
  alias Citadel.TraceEnvelope

  @recent_signal_window_size 32

  def start_link(opts) do
    name = Keyword.get(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def snapshot(server) do
    GenServer.call(server, :snapshot)
  end

  def commit_transition(server, state_changes, opts \\ []) do
    GenServer.call(server, {:commit_transition, state_changes, opts}, :infinity)
  end

  def record_host_acceptance(server, opts \\ []) do
    commit_transition(server, %{}, Keyword.put_new(opts, :meaningful_activity?, true))
  end

  def record_runtime_observation(server, %RuntimeObservation{} = observation) do
    GenServer.call(server, {:record_runtime_observation, observation}, :infinity)
  end

  def record_rejection(server, %DecisionRejection{} = rejection, opts \\ []) do
    commit_transition(server, %{last_rejection: rejection}, opts)
  end

  def replace_pending_entry(
        server,
        replaced_entry_id,
        %ActionOutboxEntry{} = replacement_entry,
        opts \\ []
      ) do
    GenServer.call(
      server,
      {:replace_pending_entry, replaced_entry_id, replacement_entry, opts},
      :infinity
    )
  end

  def replay_pending(server) do
    GenServer.call(server, :replay_pending, :infinity)
  end

  @impl true
  def init(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    clock = Keyword.get(opts, :clock, SystemClock)
    session_directory = Keyword.get(opts, :session_directory, SessionDirectory)
    signal_ingress = Keyword.get(opts, :signal_ingress, SignalIngress)

    base_state = %{
      session_id: session_id,
      clock: clock,
      session_directory: session_directory,
      kernel_snapshot: Keyword.get(opts, :kernel_snapshot, KernelSnapshot),
      boundary_lease_tracker: Keyword.get(opts, :boundary_lease_tracker, BoundaryLeaseTracker),
      service_catalog: Keyword.get(opts, :service_catalog, ServiceCatalog),
      signal_ingress: signal_ingress,
      invocation_supervisor:
        Keyword.get(opts, :invocation_supervisor, Citadel.Runtime.InvocationDispatchSupervisor),
      projection_supervisor:
        Keyword.get(opts, :projection_supervisor, Citadel.Runtime.ProjectionDispatchSupervisor),
      local_supervisor:
        Keyword.get(opts, :local_supervisor, Citadel.Runtime.LocalDispatchSupervisor),
      invocation_handler:
        Keyword.get(opts, :invocation_handler, fn _payload, entry ->
          {:ok, "invocation/#{entry.entry_id}"}
        end),
      projection_handler:
        Keyword.get(opts, :projection_handler, fn _action_kind, _payload, entry ->
          {:ok, "projection/#{entry.entry_id}"}
        end),
      local_handler:
        Keyword.get(opts, :local_handler, fn _action, entry, _state ->
          {:ok, "local/#{entry.entry_id}"}
        end),
      trace_publisher: Keyword.get(opts, :trace_publisher),
      redecision_notifier: Keyword.get(opts, :redecision_notifier),
      idle_timeout_ms: Keyword.get(opts, :idle_timeout_ms, nil),
      recent_signal_window_size:
        Keyword.get(opts, :recent_signal_window_size, @recent_signal_window_size),
      dispatching_entry_ids: MapSet.new(),
      trace_id: Keyword.get(opts, :trace_id, "trace/#{session_id}"),
      request_id: Keyword.get(opts, :request_id),
      tenant_id: Keyword.get(opts, :tenant_id),
      session_state: nil
    }

    {session_state, lifecycle_event, base_state} = bootstrap_session(base_state, opts)

    state =
      base_state
      |> Map.put(:session_state, session_state)
      |> ensure_invariants!()

    publish_bootstrap_traces(state, lifecycle_event)
    maybe_register_with_ingress_and_directory(state, lifecycle_event, opts)
    send(self(), :replay_pending)

    {:ok, state, next_timeout(state)}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    {:reply, state.session_state, state, next_timeout(state)}
  end

  def handle_call({:commit_transition, state_changes, opts}, _from, state) do
    result = apply_transition_commit(state, state_changes, opts)

    case result do
      {:ok, next_state} ->
        send(self(), :replay_pending)
        {:reply, {:ok, next_state.session_state}, next_state, next_timeout(next_state)}

      {:error, reason, next_state} ->
        {:reply, {:error, reason}, next_state, next_timeout(next_state)}
    end
  end

  def handle_call(
        {:replace_pending_entry, replaced_entry_id, %ActionOutboxEntry{} = replacement_entry,
         opts},
        _from,
        state
      ) do
    current_entry = Map.get(state.session_state.outbox.entries_by_id, replaced_entry_id)

    if is_nil(current_entry) do
      {:reply, {:error, :entry_not_found}, state, next_timeout(state)}
    else
      superseded_entry =
        ActionOutboxEntry.new!(%{
          ActionOutboxEntry.dump(current_entry)
          | replay_status: :superseded,
            extensions:
              Map.merge(current_entry.extensions, %{"superseded_by" => replacement_entry.entry_id})
        })

      updated_outbox =
        state.session_state.outbox
        |> SessionOutbox.put_entry!(superseded_entry)
        |> SessionOutbox.put_entry!(replacement_entry)

      result =
        apply_transition_commit(
          state,
          %{outbox: updated_outbox},
          Keyword.put(opts, :meaningful_activity?, true)
        )

      case result do
        {:ok, next_state} ->
          send(self(), :replay_pending)
          {:reply, {:ok, next_state.session_state}, next_state, next_timeout(next_state)}

        {:error, reason, next_state} ->
          {:reply, {:error, reason}, next_state, next_timeout(next_state)}
      end
    end
  end

  def handle_call(
        {:record_runtime_observation, %RuntimeObservation{} = observation},
        _from,
        state
      ) do
    case apply_runtime_observation(state, observation) do
      {:ok, next_state} ->
        {:reply, :ok, next_state, next_timeout(next_state)}

      {:error, reason, next_state} ->
        {:reply, {:error, reason}, next_state, next_timeout(next_state)}
    end
  end

  def handle_call(:replay_pending, _from, state) do
    state = schedule_replay(state)
    {:reply, :ok, state, next_timeout(state)}
  end

  @impl true
  def handle_info(:replay_pending, state) do
    state = schedule_replay(state)
    {:noreply, state, next_timeout(state)}
  end

  def handle_info({:runtime_observation, observation}, state) do
    case apply_runtime_observation(state, observation) do
      {:ok, next_state} ->
        {:noreply, next_state, next_timeout(next_state)}

      {:error, _reason, next_state} ->
        {:noreply, next_state, next_timeout(next_state)}
    end
  end

  def handle_info(
        {:dispatch_result, entry_id, {:accepted, acceptance}, dispatch_family},
        state
      ) do
    state =
      state
      |> Map.put(:dispatching_entry_ids, MapSet.delete(state.dispatching_entry_ids, entry_id))
      |> ensure_invariants!()

    case Map.get(state.session_state.outbox.entries_by_id, entry_id) do
      nil ->
        {:noreply, state, next_timeout(state)}

      entry ->
        case normalize_submission_acceptance(acceptance) do
          {:ok, acceptance_data} ->
            accepted_entry =
              ActionOutboxEntry.new!(%{
                ActionOutboxEntry.dump(entry)
                | replay_status: :submission_accepted,
                  submission_key: acceptance_data.submission_key,
                  submission_receipt_ref: acceptance_data.submission_receipt_ref,
                  submission_rejection: nil,
                  last_error_code: nil,
                  next_attempt_at: nil
              })

            updated_outbox =
              SessionOutbox.put_entry!(state.session_state.outbox, accepted_entry)

            case apply_transition_commit(
                   state,
                   %{outbox: updated_outbox},
                   meaningful_activity?: true
                 ) do
              {:ok, next_state} ->
                publish_action_trace(next_state, entry_id, dispatch_family, :accepted)
                send(self(), :replay_pending)
                {:noreply, next_state, next_timeout(next_state)}

              {:error, _reason, next_state} ->
                {:noreply, next_state, next_timeout(next_state)}
            end

          {:error, reason_code} ->
            case classify_failed_entry(state, entry, reason_code) do
              {:ok, next_state} ->
                publish_action_trace(next_state, entry_id, dispatch_family, :error)
                send(self(), :replay_pending)
                {:noreply, next_state, next_timeout(next_state)}

              {:error, _reason, next_state} ->
                {:noreply, next_state, next_timeout(next_state)}
            end
        end
    end
  end

  def handle_info(
        {:dispatch_result, entry_id, {:rejected, rejection}, dispatch_family},
        state
      ) do
    state =
      state
      |> Map.put(:dispatching_entry_ids, MapSet.delete(state.dispatching_entry_ids, entry_id))
      |> ensure_invariants!()

    case Map.get(state.session_state.outbox.entries_by_id, entry_id) do
      nil ->
        {:noreply, state, next_timeout(state)}

      entry ->
        case normalize_submission_rejection(rejection) do
          {:ok, rejection_data} ->
            case classify_submission_rejection(state, entry, rejection_data) do
              {:ok, next_state} ->
                publish_action_trace(next_state, entry_id, dispatch_family, :rejected)
                send(self(), :replay_pending)
                {:noreply, next_state, next_timeout(next_state)}

              {:error, _reason, next_state} ->
                {:noreply, next_state, next_timeout(next_state)}
            end

          {:error, reason_code} ->
            case classify_failed_entry(state, entry, reason_code) do
              {:ok, next_state} ->
                publish_action_trace(next_state, entry_id, dispatch_family, :error)
                send(self(), :replay_pending)
                {:noreply, next_state, next_timeout(next_state)}

              {:error, _reason, next_state} ->
                {:noreply, next_state, next_timeout(next_state)}
            end
        end
    end
  end

  def handle_info(
        {:dispatch_result, entry_id, {:ok, durable_receipt_ref}, dispatch_family},
        state
      ) do
    state =
      state
      |> Map.put(:dispatching_entry_ids, MapSet.delete(state.dispatching_entry_ids, entry_id))
      |> ensure_invariants!()

    case Map.get(state.session_state.outbox.entries_by_id, entry_id) do
      nil ->
        {:noreply, state, next_timeout(state)}

      entry ->
        completed_entry =
          ActionOutboxEntry.new!(%{
            ActionOutboxEntry.dump(entry)
            | replay_status: :completed,
              durable_receipt_ref: durable_receipt_ref,
              next_attempt_at: nil
          })

        updated_outbox = SessionOutbox.put_entry!(state.session_state.outbox, completed_entry)

        case apply_transition_commit(state, %{outbox: updated_outbox}, meaningful_activity?: true) do
          {:ok, next_state} ->
            publish_action_trace(next_state, entry_id, dispatch_family, :ok)
            send(self(), :replay_pending)
            {:noreply, next_state, next_timeout(next_state)}

          {:error, _reason, next_state} ->
            {:noreply, next_state, next_timeout(next_state)}
        end
    end
  end

  def handle_info({:dispatch_result, entry_id, {:error, reason_code}, dispatch_family}, state) do
    state =
      state
      |> Map.put(:dispatching_entry_ids, MapSet.delete(state.dispatching_entry_ids, entry_id))
      |> ensure_invariants!()

    case Map.get(state.session_state.outbox.entries_by_id, entry_id) do
      nil ->
        {:noreply, state, next_timeout(state)}

      entry ->
        case classify_failed_entry(state, entry, reason_code) do
          {:ok, next_state} ->
            publish_action_trace(next_state, entry_id, dispatch_family, :error)
            send(self(), :replay_pending)
            {:noreply, next_state, next_timeout(next_state)}

          {:error, _reason, next_state} ->
            {:noreply, next_state, next_timeout(next_state)}
        end
    end
  end

  def handle_info(:timeout, state) do
    case state.idle_timeout_ms do
      nil ->
        {:noreply, state}

      _idle_timeout_ms ->
        if state.session_state.lifecycle_status in [:active, :idle] do
          case apply_transition_commit(
                 state,
                 %{lifecycle_status: :idle, last_active_at: state.clock.utc_now()},
                 meaningful_activity?: false
               ) do
            {:ok, next_state} -> {:noreply, next_state, next_timeout(next_state)}
            {:error, _reason, next_state} -> {:noreply, next_state, next_timeout(next_state)}
          end
        else
          {:noreply, state, next_timeout(state)}
        end
    end
  end

  defp bootstrap_session(state, opts) do
    case SessionDirectory.claim_session(state.session_directory, state.session_id, opts) do
      {:ok, %{blob: claimed_blob, lifecycle_event: lifecycle_event}} ->
        case resolve_boundary_view(state, claimed_blob) do
          {:ok, boundary_lease_view} ->
            visible_services = ServiceCatalog.visible_services(state.service_catalog)

            session_state =
              build_session_state(claimed_blob, visible_services, boundary_lease_view)

            state = %{state | trace_id: trace_id_from_blob(state.trace_id, claimed_blob)}
            state = %{state | session_state: session_state}
            {state, _superseded?} = supersede_stale_entries_before_replay(state)
            {state.session_state, lifecycle_event, state}

          {:error, reason}
          when reason in [:bootstrap_timeout, :resume_wait_exhausted, :circuit_open] ->
            {blocked_state(state, :blocked), :blocked, state}

          {:error, _reason} ->
            :ok =
              SessionDirectory.quarantine_session(
                state.session_directory,
                state.session_id,
                "boundary_resume_failed"
              )

            {blocked_state(state, :quarantined), :quarantined, state}
        end

      {:error, {:migration_failed, _reason}} ->
        :ok =
          SessionDirectory.quarantine_session(
            state.session_directory,
            state.session_id,
            "schema_migration_failed"
          )

        {blocked_state(state, :quarantined), :quarantined, state}

      {:error, reason}
      when reason in [:bootstrap_timeout, :resume_wait_exhausted, :circuit_open] ->
        {blocked_state(state, :blocked), :blocked, state}

      {:error, _reason} ->
        :ok =
          SessionDirectory.quarantine_session(
            state.session_directory,
            state.session_id,
            "continuity_corrupted"
          )

        {blocked_state(state, :quarantined), :quarantined, state}
    end
  end

  defp blocked_state(state, lifecycle_status) do
    SessionState.new!(%{
      session_id: state.session_id,
      continuity_revision: 0,
      owner_incarnation: 1,
      project_binding: nil,
      scope_ref: nil,
      signal_cursor: nil,
      recent_signal_hashes: [],
      last_active_at: state.clock.utc_now(),
      lifecycle_status: lifecycle_status,
      active_plan: nil,
      active_authority_decision: nil,
      last_rejection: nil,
      visible_services: [],
      boundary_lease_view: nil,
      outbox: SessionOutbox.from_entries!([]),
      external_refs: %{},
      extensions: %{}
    })
  end

  defp resolve_boundary_view(state, %PersistedSessionBlob{} = claimed_blob) do
    case claimed_blob.envelope.boundary_ref do
      nil ->
        {:ok, nil}

      boundary_ref ->
        BoundaryLeaseTracker.classify_for_resume(state.boundary_lease_tracker, boundary_ref)
    end
  end

  defp build_session_state(
         %PersistedSessionBlob{} = claimed_blob,
         visible_services,
         boundary_lease_view
       ) do
    SessionState.new!(%{
      session_id: claimed_blob.session_id,
      continuity_revision: claimed_blob.envelope.continuity_revision,
      owner_incarnation: claimed_blob.envelope.owner_incarnation,
      project_binding: claimed_blob.envelope.project_binding,
      scope_ref: claimed_blob.envelope.scope_ref,
      signal_cursor: claimed_blob.envelope.signal_cursor,
      recent_signal_hashes: claimed_blob.envelope.recent_signal_hashes,
      last_active_at: claimed_blob.envelope.last_active_at,
      lifecycle_status: claimed_blob.envelope.lifecycle_status,
      active_plan: claimed_blob.envelope.active_plan,
      active_authority_decision: claimed_blob.envelope.active_authority_decision,
      last_rejection: claimed_blob.envelope.last_rejection,
      visible_services: visible_services,
      boundary_lease_view: boundary_lease_view,
      outbox: PersistedSessionBlob.restore_session_outbox!(claimed_blob),
      external_refs: claimed_blob.envelope.external_refs,
      extensions: claimed_blob.envelope.extensions
    })
  end

  defp trace_id_from_blob(default_trace_id, %PersistedSessionBlob{} = claimed_blob) do
    Map.get(claimed_blob.envelope.external_refs, "trace_id", default_trace_id)
  end

  defp publish_bootstrap_traces(state, lifecycle_event) do
    case lifecycle_event do
      :attached ->
        publish_trace_family(state, "session_attached", %{status: "ok"})

      :resumed ->
        publish_trace_family(state, "session_resumed", %{status: "ok"})

      :blocked ->
        publish_trace_family(state, "session_blocked", %{status: "error"})

      :quarantined ->
        publish_trace_family(state, "session_quarantined", %{status: "error"})

      _ ->
        :ok
    end

    if lifecycle_event == :resumed and replayable_entries?(state.session_state.outbox) do
      publish_trace_family(state, "session_crash_recovery_triggered", %{status: "ok"})
    end
  end

  defp maybe_register_with_ingress_and_directory(state, lifecycle_event, opts) do
    priority_class =
      cond do
        lifecycle_event in [:blocked] -> "blocked"
        Keyword.get(opts, :explicit_resume, false) -> "explicit_resume"
        replayable_entries?(state.session_state.outbox) -> "pending_replay_safe"
        true -> "background"
      end

    SessionDirectory.register_active_session(
      state.session_directory,
      state.session_id,
      committed_signal_cursor: state.session_state.signal_cursor,
      priority_class: priority_class,
      pending_replay_safe: replayable_entries?(state.session_state.outbox),
      live_request: false
    )

    if lifecycle_event not in [:blocked, :quarantined] do
      :ok =
        SignalIngress.register_subscription(state.signal_ingress, state.session_id,
          committed_signal_cursor: state.session_state.signal_cursor,
          priority_class: priority_class
        )

      :ok = SignalIngress.register_consumer(state.signal_ingress, state.session_id, self())
    end
  end

  defp supersede_stale_entries_before_replay(state) do
    snapshot = KernelSnapshot.current_snapshot(state.kernel_snapshot)

    stale_entry_ids =
      state.session_state.outbox.entry_order
      |> Enum.filter(fn entry_id ->
        entry = Map.fetch!(state.session_state.outbox.entries_by_id, entry_id)

        entry.replay_status in [:pending, :dispatched] and
          Staleness.stale?(entry, snapshot, state.session_state)
      end)

    if stale_entry_ids == [] do
      {state, false}
    else
      updated_outbox =
        Enum.reduce(stale_entry_ids, state.session_state.outbox, fn entry_id, outbox ->
          stale_entry = Map.fetch!(outbox.entries_by_id, entry_id)

          superseded_entry =
            ActionOutboxEntry.new!(%{
              ActionOutboxEntry.dump(stale_entry)
              | replay_status: :superseded,
                extensions:
                  Map.merge(stale_entry.extensions, %{"superseded_reason" => "resume_stale"})
            })

          SessionOutbox.put_entry!(outbox, superseded_entry)
        end)
        |> ensure_redecision_entry(state.session_state, snapshot, state.clock.utc_now())

      case apply_transition_commit(state, %{outbox: updated_outbox}, meaningful_activity?: true) do
        {:ok, next_state} ->
          publish_trace_family(next_state, "redecision_triggered", %{status: "ok"})
          {next_state, true}

        {:error, _reason, next_state} ->
          {next_state, false}
      end
    end
  end

  defp ensure_redecision_entry(%SessionOutbox{} = outbox, session_state, snapshot, now) do
    existing_redecision? =
      outbox.entries_by_id
      |> Map.values()
      |> Enum.any?(
        &(&1.action.action_kind == "enqueue_redecision" and
            &1.replay_status in [:pending, :dispatched])
      )

    if existing_redecision? do
      outbox
    else
      SessionOutbox.put_entry!(outbox, build_local_redecision_entry(session_state, snapshot, now))
    end
  end

  defp build_local_redecision_entry(session_state, snapshot, now) do
    ActionOutboxEntry.new!(%{
      schema_version: 1,
      entry_id: generate_entry_id("redecision"),
      causal_group_id: "redecision/#{session_state.session_id}",
      action:
        LocalAction.new!(%{
          action_kind: "enqueue_redecision",
          payload: %{"session_id" => session_state.session_id},
          extensions: %{}
        }),
      inserted_at: now,
      replay_status: :pending,
      durable_receipt_ref: nil,
      attempt_count: 0,
      max_attempts: 1,
      backoff_policy: default_backoff_policy(),
      next_attempt_at: nil,
      last_error_code: nil,
      dead_letter_reason: nil,
      ordering_mode: :relaxed,
      staleness_mode: :stale_exempt,
      staleness_requirements: nil,
      extensions: %{
        "snapshot_seq" => snapshot.snapshot_seq
      }
    })
  end

  defp apply_transition_commit(state, state_changes, opts) do
    next_session_state = build_next_session_state(state, state_changes, opts)

    candidate_state =
      state
      |> Map.put(:session_state, next_session_state)
      |> ensure_invariants!()

    persisted_blob = persisted_blob_from_session_state(candidate_state.session_state)

    commit =
      SessionContinuityCommit.new!(%{
        session_id: state.session_id,
        expected_continuity_revision: state.session_state.continuity_revision,
        expected_owner_incarnation: state.session_state.owner_incarnation,
        persisted_blob: persisted_blob,
        extensions: %{}
      })

    case SessionDirectory.commit_continuity(state.session_directory, commit) do
      {:ok, applied_blob} ->
        next_state =
          state
          |> Map.put(
            :session_state,
            build_session_state(
              applied_blob,
              candidate_state.session_state.visible_services,
              candidate_state.session_state.boundary_lease_view
            )
          )
          |> ensure_invariants!()

        {:ok, next_state}

      {:error, reason} ->
        {:error, reason, state}
    end
  end

  defp build_next_session_state(state, state_changes, opts) do
    state_changes =
      case state_changes do
        fun when is_function(fun, 1) -> fun.(state.session_state)
        map when is_map(map) -> map
      end

    last_active_at =
      if Keyword.get(opts, :meaningful_activity?, true) do
        Map.get(state_changes, :last_active_at, state.clock.utc_now())
      else
        Map.get(state_changes, :last_active_at, state.session_state.last_active_at)
      end

    base_map =
      state.session_state
      |> SessionState.dump()
      |> Map.merge(Map.new(state_changes))
      |> Map.put(:last_active_at, last_active_at)

    SessionState.new!(base_map)
  end

  defp persisted_blob_from_session_state(%SessionState{} = session_state) do
    PersistedSessionBlob.new!(%{
      schema_version: 1,
      session_id: session_state.session_id,
      envelope:
        PersistedSessionEnvelope.new!(%{
          schema_version: 1,
          session_id: session_state.session_id,
          continuity_revision: session_state.continuity_revision + 1,
          owner_incarnation: session_state.owner_incarnation,
          project_binding: session_state.project_binding,
          scope_ref: session_state.scope_ref,
          signal_cursor: session_state.signal_cursor,
          recent_signal_hashes: session_state.recent_signal_hashes,
          lifecycle_status: session_state.lifecycle_status,
          last_active_at: session_state.last_active_at,
          active_plan: session_state.active_plan,
          active_authority_decision: session_state.active_authority_decision,
          last_rejection: session_state.last_rejection,
          boundary_ref: current_boundary_ref(session_state.boundary_lease_view),
          outbox_entry_ids: session_state.outbox.entry_order,
          external_refs: session_state.external_refs,
          extensions: session_state.extensions
        }),
      outbox_entries: session_state.outbox.entries_by_id,
      extensions: %{}
    })
  end

  defp current_boundary_ref(nil), do: nil
  defp current_boundary_ref(boundary_lease_view), do: boundary_lease_view.boundary_ref

  defp replayable_entries?(%SessionOutbox{} = outbox) do
    Enum.any?(outbox.entries_by_id, fn {_entry_id, entry} ->
      entry.replay_status in [:pending, :dispatched]
    end)
  end

  defp schedule_replay(state) do
    now = state.clock.utc_now()

    eligible_entries =
      state.session_state.outbox.entry_order
      |> Enum.map(&Map.fetch!(state.session_state.outbox.entries_by_id, &1))
      |> eligible_replay_entries(now)

    Enum.reduce(eligible_entries, state, fn entry, state_acc ->
      maybe_dispatch_entry(state_acc, entry)
    end)
  end

  defp eligible_replay_entries(entries, now) do
    {eligible, _strict_barrier?} =
      Enum.reduce(entries, {[], false}, fn entry, {acc, strict_barrier?} ->
        cond do
          entry.ordering_mode == :strict and
              entry.replay_status in [:completed, :submission_accepted, :superseded] ->
            {acc, strict_barrier?}

          entry.ordering_mode == :strict and entry.replay_status == :dead_letter ->
            {acc, true}

          entry.ordering_mode == :strict and strict_barrier? ->
            {acc, true}

          entry.ordering_mode == :strict and replay_ready?(entry, now) ->
            {[entry | acc], true}

          entry.ordering_mode == :strict ->
            {acc, true}

          replay_ready?(entry, now) ->
            {[entry | acc], strict_barrier?}

          true ->
            {acc, strict_barrier?}
        end
      end)

    Enum.reverse(eligible)
  end

  defp replay_ready?(entry, now) do
    entry.replay_status in [:pending, :dispatched] and
      (is_nil(entry.next_attempt_at) or DateTime.compare(entry.next_attempt_at, now) != :gt)
  end

  defp apply_runtime_observation(state, %RuntimeObservation{} = observation) do
    if observation.signal_id in state.session_state.recent_signal_hashes do
      {:ok, state}
    else
      trimmed_hashes =
        [observation.signal_id | state.session_state.recent_signal_hashes]
        |> Enum.uniq()
        |> Enum.take(state.recent_signal_window_size)

      state_changes = %{
        signal_cursor: observation.signal_cursor || state.session_state.signal_cursor,
        recent_signal_hashes: trimmed_hashes,
        last_active_at: state.clock.utc_now()
      }

      case apply_transition_commit(state, state_changes, meaningful_activity?: true) do
        {:ok, next_state} -> {:ok, next_state}
        {:error, reason, next_state} -> {:error, reason, next_state}
      end
    end
  end

  defp maybe_dispatch_entry(state, entry) do
    cond do
      MapSet.member?(state.dispatching_entry_ids, entry.entry_id) ->
        state

      entry.staleness_mode == :requires_check and
          Staleness.stale?(
            entry,
            KernelSnapshot.current_snapshot(state.kernel_snapshot),
            state.session_state
          ) ->
        supersede_entry_with_redecision(state, entry.entry_id)

      true ->
        dispatch_entry(state, entry)
    end
  end

  defp supersede_entry_with_redecision(state, entry_id) do
    stale_entry = Map.fetch!(state.session_state.outbox.entries_by_id, entry_id)

    superseded_entry =
      ActionOutboxEntry.new!(%{
        ActionOutboxEntry.dump(stale_entry)
        | replay_status: :superseded,
          extensions:
            Map.merge(stale_entry.extensions, %{"superseded_reason" => "stale_before_dispatch"})
      })

    snapshot = KernelSnapshot.current_snapshot(state.kernel_snapshot)

    updated_outbox =
      state.session_state.outbox
      |> SessionOutbox.put_entry!(superseded_entry)
      |> ensure_redecision_entry(state.session_state, snapshot, state.clock.utc_now())

    case apply_transition_commit(state, %{outbox: updated_outbox}, meaningful_activity?: true) do
      {:ok, next_state} ->
        publish_trace_family(next_state, "redecision_triggered", %{status: "ok"})
        next_state

      {:error, _reason, next_state} ->
        next_state
    end
  end

  defp dispatch_entry(state, entry) do
    attempted_entry =
      ActionOutboxEntry.new!(%{
        ActionOutboxEntry.dump(entry)
        | replay_status: :dispatched,
          attempt_count: entry.attempt_count + 1,
          next_attempt_at: nil
      })

    updated_outbox = SessionOutbox.put_entry!(state.session_state.outbox, attempted_entry)

    case apply_transition_commit(state, %{outbox: updated_outbox}, meaningful_activity?: false) do
      {:ok, next_state} ->
        dispatch_family = dispatch_family(entry.action.action_kind)

        case start_dispatch_task(next_state, dispatch_family, attempted_entry) do
          {:ok, next_state} ->
            publish_trace_family(next_state, "outbox_entry_replayed", %{
              outbox_entry_id: attempted_entry.entry_id,
              status: "ok"
            })

            next_state

          {:error, next_state} ->
            revert_dispatch_started(next_state, entry)
        end

      {:error, _reason, next_state} ->
        next_state
    end
  end

  defp start_dispatch_task(state, dispatch_family, entry) do
    supervisor = supervisor_for_family(state, dispatch_family)
    server = self()

    task_fun = fn ->
      result = perform_action(state, dispatch_family, entry)
      send(server, {:dispatch_result, entry.entry_id, result, dispatch_family})
    end

    case Task.Supervisor.start_child(supervisor, task_fun) do
      {:ok, _pid} ->
        {:ok,
         state
         |> Map.put(
           :dispatching_entry_ids,
           MapSet.put(state.dispatching_entry_ids, entry.entry_id)
         )
         |> ensure_invariants!()}

      {:error, _reason} ->
        emit_dispatch_backlog(dispatch_family)
        {:error, state}
    end
  end

  defp revert_dispatch_started(state, original_entry) do
    reverted_outbox = SessionOutbox.put_entry!(state.session_state.outbox, original_entry)

    case apply_transition_commit(state, %{outbox: reverted_outbox}, meaningful_activity?: false) do
      {:ok, next_state} -> next_state
      {:error, _reason, next_state} -> next_state
    end
  end

  defp perform_action(state, :invocation, entry) do
    state.invocation_handler.(entry.action.payload, entry)
  end

  defp perform_action(state, :projection, entry) do
    state.projection_handler.(entry.action.action_kind, entry.action.payload, entry)
  end

  defp perform_action(state, :local, entry) do
    case entry.action.action_kind do
      "service_catalog_register" ->
        {:ok, _epoch} =
          ServiceCatalog.register_service(
            state.service_catalog,
            ServiceDescriptor.new!(entry.action.payload["service_descriptor"])
          )

        {:ok, "service_catalog/#{entry.entry_id}"}

      "service_catalog_update" ->
        {:ok, _epoch} =
          ServiceCatalog.update_service(
            state.service_catalog,
            ServiceDescriptor.new!(entry.action.payload["service_descriptor"])
          )

        {:ok, "service_catalog/#{entry.entry_id}"}

      "service_catalog_retire" ->
        {:ok, _epoch} =
          ServiceCatalog.retire_service(state.service_catalog, entry.action.payload["service_id"])

        {:ok, "service_catalog/#{entry.entry_id}"}

      "enqueue_redecision" ->
        maybe_notify_redecision(state, entry)
        {:ok, "redecision/#{entry.entry_id}"}

      _ ->
        state.local_handler.(entry.action, entry, state)
    end
  end

  defp maybe_notify_redecision(%{redecision_notifier: nil}, _entry), do: :ok

  defp maybe_notify_redecision(%{redecision_notifier: notifier, session_id: session_id}, entry)
       when is_pid(notifier) do
    send(notifier, {:redecision_requested, session_id, entry.entry_id})
  end

  defp maybe_notify_redecision(_state, _entry), do: :ok

  defp classify_failed_entry(state, entry, reason_code) do
    if entry.attempt_count >= entry.max_attempts do
      dead_letter_entry =
        ActionOutboxEntry.new!(%{
          ActionOutboxEntry.dump(entry)
          | replay_status: :dead_letter,
            last_error_code: Atom.to_string(reason_code),
            dead_letter_reason: Atom.to_string(reason_code),
            next_attempt_at: nil
        })

      updated_session_state =
        if dead_letter_entry.ordering_mode == :strict do
          %{
            outbox: SessionOutbox.put_entry!(state.session_state.outbox, dead_letter_entry),
            lifecycle_status: :blocked,
            extensions:
              Map.merge(state.session_state.extensions, %{
                "blocked_failure" => %{
                  "entry_id" => dead_letter_entry.entry_id,
                  "reason_family" => dead_letter_entry.dead_letter_reason,
                  "last_error_code" => dead_letter_entry.last_error_code
                }
              })
          }
        else
          %{outbox: SessionOutbox.put_entry!(state.session_state.outbox, dead_letter_entry)}
        end

      :telemetry.execute(
        Telemetry.event_name(:outbox_dead_letter_count),
        %{count: 1},
        %{reason_family: dead_letter_entry.dead_letter_reason}
      )

      apply_transition_commit(state, updated_session_state, meaningful_activity?: true)
    else
      delay_ms =
        BackoffPolicy.compute_delay_ms!(entry.backoff_policy, entry.entry_id, entry.attempt_count)

      next_attempt_at = DateTime.add(state.clock.utc_now(), delay_ms, :millisecond)

      retriable_entry =
        ActionOutboxEntry.new!(%{
          ActionOutboxEntry.dump(entry)
          | replay_status: :pending,
            next_attempt_at: next_attempt_at,
            last_error_code: Atom.to_string(reason_code)
        })

      apply_transition_commit(
        state,
        %{outbox: SessionOutbox.put_entry!(state.session_state.outbox, retriable_entry)},
        meaningful_activity?: false
      )
    end
  end

  defp classify_submission_rejection(state, entry, rejection) do
    case rejection.retry_class do
      :retryable ->
        delay_ms =
          BackoffPolicy.compute_delay_ms!(
            entry.backoff_policy,
            entry.entry_id,
            entry.attempt_count
          )

        next_attempt_at = DateTime.add(state.clock.utc_now(), delay_ms, :millisecond)

        retriable_entry =
          ActionOutboxEntry.new!(%{
            ActionOutboxEntry.dump(entry)
            | replay_status: :pending,
              submission_key: rejection.submission_key,
              submission_receipt_ref: nil,
              submission_rejection: rejection_to_map(rejection),
              next_attempt_at: next_attempt_at,
              last_error_code: rejection.reason_code
          })

        apply_transition_commit(
          state,
          %{outbox: SessionOutbox.put_entry!(state.session_state.outbox, retriable_entry)},
          meaningful_activity?: false
        )

      :after_redecision ->
        superseded_entry =
          ActionOutboxEntry.new!(%{
            ActionOutboxEntry.dump(entry)
            | replay_status: :superseded,
              submission_key: rejection.submission_key,
              submission_receipt_ref: nil,
              submission_rejection: rejection_to_map(rejection),
              last_error_code: rejection.reason_code,
              next_attempt_at: nil,
              extensions:
                Map.merge(entry.extensions, %{
                  "superseded_reason" => "submission_rejected_after_redecision"
                })
          })

        snapshot = KernelSnapshot.current_snapshot(state.kernel_snapshot)

        updated_outbox =
          state.session_state.outbox
          |> SessionOutbox.put_entry!(superseded_entry)
          |> ensure_redecision_entry(state.session_state, snapshot, state.clock.utc_now())

        apply_transition_commit(
          state,
          %{outbox: updated_outbox},
          meaningful_activity?: true
        )

      :never ->
        dead_letter_entry =
          ActionOutboxEntry.new!(%{
            ActionOutboxEntry.dump(entry)
            | replay_status: :dead_letter,
              submission_key: rejection.submission_key,
              submission_receipt_ref: nil,
              submission_rejection: rejection_to_map(rejection),
              last_error_code: rejection.reason_code,
              dead_letter_reason: rejection.reason_code,
              next_attempt_at: nil
          })

        updated_session_state =
          if dead_letter_entry.ordering_mode == :strict do
            %{
              outbox: SessionOutbox.put_entry!(state.session_state.outbox, dead_letter_entry),
              lifecycle_status: :blocked,
              extensions:
                Map.merge(state.session_state.extensions, %{
                  "blocked_failure" => %{
                    "entry_id" => dead_letter_entry.entry_id,
                    "reason_family" => dead_letter_entry.dead_letter_reason,
                    "last_error_code" => dead_letter_entry.last_error_code
                  }
                })
            }
          else
            %{outbox: SessionOutbox.put_entry!(state.session_state.outbox, dead_letter_entry)}
          end

        :telemetry.execute(
          Telemetry.event_name(:outbox_dead_letter_count),
          %{count: 1},
          %{reason_family: dead_letter_entry.dead_letter_reason}
        )

        apply_transition_commit(state, updated_session_state, meaningful_activity?: true)
    end
  end

  defp publish_trace_family(%{trace_publisher: nil}, _family, _attrs), do: :ok

  defp publish_trace_family(state, family, attrs) do
    snapshot_seq =
      case KernelSnapshot.current_snapshot(state.kernel_snapshot) do
        %{snapshot_seq: value} -> value
        _ -> nil
      end

    envelope =
      TraceEnvelope.new!(%{
        trace_envelope_id: generate_entry_id("trace"),
        record_kind: :event,
        family: family,
        name: Trace.canonical_event_name!(family),
        phase: "post_commit",
        trace_id: state.trace_id,
        tenant_id: state.tenant_id,
        session_id: state.session_id,
        request_id: state.request_id,
        decision_id: nil,
        snapshot_seq: snapshot_seq,
        signal_id: Map.get(attrs, :signal_id),
        outbox_entry_id: Map.get(attrs, :outbox_entry_id),
        boundary_ref: current_boundary_ref(state.session_state.boundary_lease_view),
        span_id: nil,
        parent_span_id: nil,
        occurred_at: state.clock.utc_now(),
        started_at: nil,
        finished_at: nil,
        status: Map.get(attrs, :status, "ok"),
        attributes: Map.get(attrs, :attributes, %{}),
        extensions: %{}
      })

    _ = Citadel.Runtime.TracePublisher.publish_trace(state.trace_publisher, envelope)
    :ok
  end

  defp publish_action_trace(state, entry_id, dispatch_family, status) do
    family =
      case dispatch_family do
        :projection -> "derived_state_attachment_published"
        :invocation -> "invocation_submitted"
        :local -> "outbox_entry_dispatched"
      end

    publish_trace_family(state, family, %{
      outbox_entry_id: entry_id,
      status: Atom.to_string(status)
    })
  end

  defp emit_dispatch_backlog(:invocation) do
    :telemetry.execute(Telemetry.event_name(:invocation_dispatch_backlog), %{count: 1}, %{})
  end

  defp emit_dispatch_backlog(:projection) do
    :telemetry.execute(Telemetry.event_name(:projection_dispatch_backlog), %{count: 1}, %{})
  end

  defp emit_dispatch_backlog(:local), do: :ok

  defp normalize_submission_acceptance(%{
         submission_key: submission_key,
         submission_receipt_ref: submission_receipt_ref,
         status: status,
         accepted_at: %DateTime{} = accepted_at,
         ledger_version: ledger_version
       })
       when is_binary(submission_key) and is_binary(submission_receipt_ref) and
              is_integer(ledger_version) and ledger_version >= 0 do
    with {:ok, normalized_status} <- normalize_submission_acceptance_status(status) do
      {:ok,
       %{
         submission_key: submission_key,
         submission_receipt_ref: submission_receipt_ref,
         status: normalized_status,
         accepted_at: accepted_at,
         ledger_version: ledger_version
       }}
    end
  end

  defp normalize_submission_acceptance(_value), do: {:error, :invalid_submission_result}

  defp normalize_submission_rejection(%{
         submission_key: submission_key,
         rejection_family: rejection_family,
         reason_code: reason_code,
         retry_class: retry_class,
         redecision_required: redecision_required,
         details: details,
         rejected_at: %DateTime{} = rejected_at
       })
       when is_binary(submission_key) and is_binary(reason_code) and
              is_boolean(redecision_required) and is_map(details) do
    with {:ok, normalized_rejection_family} <-
           normalize_submission_rejection_family(rejection_family),
         {:ok, normalized_retry_class} <- normalize_submission_retry_class(retry_class) do
      {:ok,
       %{
         submission_key: submission_key,
         rejection_family: normalized_rejection_family,
         reason_code: reason_code,
         retry_class: normalized_retry_class,
         redecision_required: redecision_required,
         details: details,
         rejected_at: rejected_at
       }}
    end
  end

  defp normalize_submission_rejection(_value), do: {:error, :invalid_submission_result}

  defp normalize_submission_acceptance_status(status) when status in [:accepted, :duplicate],
    do: {:ok, status}

  defp normalize_submission_acceptance_status("accepted"), do: {:ok, :accepted}
  defp normalize_submission_acceptance_status("duplicate"), do: {:ok, :duplicate}
  defp normalize_submission_acceptance_status(_status), do: {:error, :invalid_submission_result}

  defp normalize_submission_rejection_family(rejection_family)
       when rejection_family in [
              :invalid_submission,
              :projection_mismatch,
              :scope_unresolvable,
              :policy_denied,
              :policy_shed,
              :unsupported_target,
              :capacity_exhausted
            ],
       do: {:ok, rejection_family}

  defp normalize_submission_rejection_family(rejection_family) when is_binary(rejection_family) do
    case rejection_family do
      "invalid_submission" -> {:ok, :invalid_submission}
      "projection_mismatch" -> {:ok, :projection_mismatch}
      "scope_unresolvable" -> {:ok, :scope_unresolvable}
      "policy_denied" -> {:ok, :policy_denied}
      "policy_shed" -> {:ok, :policy_shed}
      "unsupported_target" -> {:ok, :unsupported_target}
      "capacity_exhausted" -> {:ok, :capacity_exhausted}
      _other -> {:error, :invalid_submission_result}
    end
  end

  defp normalize_submission_rejection_family(_rejection_family),
    do: {:error, :invalid_submission_result}

  defp normalize_submission_retry_class(retry_class)
       when retry_class in [:never, :after_redecision, :retryable],
       do: {:ok, retry_class}

  defp normalize_submission_retry_class("never"), do: {:ok, :never}
  defp normalize_submission_retry_class("after_redecision"), do: {:ok, :after_redecision}
  defp normalize_submission_retry_class("retryable"), do: {:ok, :retryable}
  defp normalize_submission_retry_class(_retry_class), do: {:error, :invalid_submission_result}

  defp rejection_to_map(rejection) when is_map(rejection) do
    rejection = Map.new(rejection) |> Map.delete(:__struct__)

    %{
      "submission_key" => map_value(rejection, :submission_key),
      "rejection_family" => map_value(rejection, :rejection_family),
      "reason_code" => map_value(rejection, :reason_code),
      "retry_class" => map_value(rejection, :retry_class),
      "redecision_required" => map_value(rejection, :redecision_required),
      "details" => map_value(rejection, :details, %{}),
      "rejected_at" =>
        map_value(rejection, :rejected_at)
        |> normalize_datetime_for_json()
    }
  end

  defp normalize_datetime_for_json(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp normalize_datetime_for_json(value) when is_binary(value), do: value

  defp map_value(map, key, default \\ nil) when is_map(map) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end

  defp dispatch_family(action_kind)
       when action_kind in ["publish_review_projection", "publish_derived_state_attachment"],
       do: :projection

  defp dispatch_family("submit_invocation"), do: :invocation
  defp dispatch_family(_action_kind), do: :local

  defp supervisor_for_family(state, :invocation), do: state.invocation_supervisor
  defp supervisor_for_family(state, :projection), do: state.projection_supervisor
  defp supervisor_for_family(state, :local), do: state.local_supervisor

  defp default_backoff_policy do
    BackoffPolicy.new!(%{
      strategy: :fixed,
      base_delay_ms: 0,
      max_delay_ms: 0,
      linear_step_ms: nil,
      multiplier: nil,
      jitter_mode: :none,
      jitter_window_ms: 0,
      extensions: %{}
    })
  end

  defp ensure_invariants!(
         %{session_id: session_id, session_state: %SessionState{} = session_state} = state
       ) do
    if session_state.session_id != session_id do
      invariant_failure!(
        "session_state.session_id #{inspect(session_state.session_id)} does not match owner session_id #{inspect(session_id)}"
      )
    end

    validate_project_binding_invariant!(session_state)
    validate_outbox_invariant!(session_state)
    validate_dispatching_entries_invariant!(state)
    validate_blocked_failure_invariant!(session_state)
    state
  end

  defp validate_project_binding_invariant!(%SessionState{project_binding: nil}), do: :ok

  defp validate_project_binding_invariant!(%SessionState{} = session_state) do
    if session_state.project_binding.session_id != session_state.session_id do
      invariant_failure!(
        "project binding session_id #{inspect(session_state.project_binding.session_id)} does not match session_state.session_id #{inspect(session_state.session_id)}"
      )
    end
  end

  defp validate_outbox_invariant!(%SessionState{} = session_state) do
    SessionOutbox.ensure_invariant!(session_state.outbox)
  rescue
    error in ArgumentError ->
      invariant_failure!(Exception.message(error))
  end

  defp validate_dispatching_entries_invariant!(state) do
    invalid_dispatching_ids =
      state.dispatching_entry_ids
      |> MapSet.to_list()
      |> Enum.reject(fn entry_id ->
        case Map.get(state.session_state.outbox.entries_by_id, entry_id) do
          %ActionOutboxEntry{replay_status: :dispatched} -> true
          _ -> false
        end
      end)

    if invalid_dispatching_ids != [] do
      invariant_failure!(
        "dispatching_entry_ids must reference dispatched outbox entries, got #{inspect(invalid_dispatching_ids)}"
      )
    end
  end

  defp validate_blocked_failure_invariant!(%SessionState{} = session_state) do
    strict_dead_letters =
      session_state.outbox.entry_order
      |> Enum.map(&Map.fetch!(session_state.outbox.entries_by_id, &1))
      |> Enum.filter(&(&1.replay_status == :dead_letter and &1.ordering_mode == :strict))

    blocked_failure = Map.get(session_state.extensions, "blocked_failure")

    if strict_dead_letters != [] and
         session_state.lifecycle_status not in [:blocked, :quarantined] do
      invariant_failure!(
        "strict dead-letter entries require blocked or quarantined lifecycle_status for session #{inspect(session_state.session_id)}"
      )
    end

    case blocked_failure do
      nil ->
        :ok

      %{"entry_id" => entry_id} ->
        entry = Map.get(session_state.outbox.entries_by_id, entry_id)

        cond do
          session_state.lifecycle_status not in [:blocked, :quarantined] ->
            invariant_failure!(
              "blocked_failure metadata requires blocked or quarantined lifecycle_status for session #{inspect(session_state.session_id)}"
            )

          is_nil(entry) ->
            invariant_failure!(
              "blocked_failure metadata references missing entry #{inspect(entry_id)}"
            )

          entry.replay_status != :dead_letter or entry.ordering_mode != :strict ->
            invariant_failure!(
              "blocked_failure metadata must reference a strict dead-letter entry, got replay_status=#{inspect(entry.replay_status)} ordering_mode=#{inspect(entry.ordering_mode)}"
            )

          Map.get(blocked_failure, "reason_family") != entry.dead_letter_reason ->
            invariant_failure!(
              "blocked_failure reason_family drifted from strict dead-letter entry #{inspect(entry_id)}"
            )

          Map.get(blocked_failure, "last_error_code") != entry.last_error_code ->
            invariant_failure!(
              "blocked_failure last_error_code drifted from strict dead-letter entry #{inspect(entry_id)}"
            )

          true ->
            :ok
        end

      other ->
        invariant_failure!(
          "blocked_failure metadata must be a JSON object, got: #{inspect(other)}"
        )
    end
  end

  defp invariant_failure!(reason) do
    raise RuntimeError, "Citadel.Runtime.SessionServer invariant failure: #{reason}"
  end

  defp next_timeout(%{idle_timeout_ms: nil}), do: :infinity
  defp next_timeout(%{idle_timeout_ms: idle_timeout_ms}), do: idle_timeout_ms

  defp generate_entry_id(prefix) do
    "#{prefix}-#{System.unique_integer([:positive, :monotonic])}"
  end
end
