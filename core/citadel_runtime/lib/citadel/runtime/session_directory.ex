defmodule Citadel.Runtime.SessionDirectory do
  @moduledoc """
  Continuity-store owner for persisted session blobs, activation policy, and
  dead-letter maintenance.
  """

  use GenServer

  alias Citadel.ActionOutboxEntry
  alias Citadel.KernelEpochUpdate
  alias Citadel.ObservabilityContract.Telemetry
  alias Citadel.PersistedSessionBlob
  alias Citadel.PersistedSessionEnvelope
  alias Citadel.ProjectBinding
  alias Citadel.SessionActivationPolicy
  alias Citadel.SessionContinuityCommit
  alias Citadel.SessionOutbox
  alias Citadel.Runtime.KernelSnapshot
  alias Citadel.Runtime.SessionMigration
  alias Citadel.Runtime.SystemClock

  @flush_message :flush_project_binding_epoch

  @type continuity_fault ::
          :ok
          | {:error, :acknowledgement_missing}
          | {:error, :acknowledgement_ambiguous, :committed}
          | {:error, :acknowledgement_ambiguous, :not_committed}

  @type state :: %{
          clock: module(),
          kernel_snapshot: term(),
          flush_interval_ms: non_neg_integer(),
          activation_policy: SessionActivationPolicy.t(),
          store_key: term(),
          store: map(),
          fault_injection: (SessionContinuityCommit.t() -> continuity_fault()) | nil,
          pending_project_binding_epoch: non_neg_integer() | nil,
          pending_updated_at: DateTime.t() | nil,
          flush_timer_ref: reference() | nil,
          activation_queue: %{
            optional(String.t()) => %{priority_class: String.t(), queued_at: DateTime.t()}
          }
        }

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def reset!(server \\ __MODULE__) do
    GenServer.call(server, :reset)
  end

  def configure_fault_injection(server \\ __MODULE__, fault_injection) do
    GenServer.call(server, {:configure_fault_injection, fault_injection})
  end

  def seed_raw_blob(server \\ __MODULE__, session_id, raw_blob) do
    GenServer.call(server, {:seed_raw_blob, session_id, raw_blob})
  end

  def fetch_persisted_blob(server \\ __MODULE__, session_id) do
    GenServer.call(server, {:fetch_persisted_blob, session_id})
  end

  def claim_session(server \\ __MODULE__, session_id, opts \\ []) do
    GenServer.call(server, {:claim_session, session_id, opts})
  end

  def commit_continuity(server \\ __MODULE__, %SessionContinuityCommit{} = commit) do
    GenServer.call(server, {:commit_continuity, commit})
  end

  def project_binding_epoch(server \\ __MODULE__) do
    GenServer.call(server, :project_binding_epoch)
  end

  def resolve_outbox_entry(server \\ __MODULE__, entry_id) do
    GenServer.call(server, {:resolve_outbox_entry, entry_id})
  end

  def register_active_session(server \\ __MODULE__, session_id, opts \\ []) do
    GenServer.call(server, {:register_active_session, session_id, opts})
  end

  def unregister_active_session(server \\ __MODULE__, session_id) do
    GenServer.call(server, {:unregister_active_session, session_id})
  end

  def list_active_session_cursors(server \\ __MODULE__) do
    GenServer.call(server, :list_active_session_cursors)
  end

  def batch_load_committed_cursors(server \\ __MODULE__, session_ids) do
    GenServer.call(server, {:batch_load_committed_cursors, session_ids})
  end

  def enqueue_activation(server \\ __MODULE__, session_id, priority_class) do
    GenServer.call(server, {:enqueue_activation, session_id, priority_class})
  end

  def next_activation_batch(server \\ __MODULE__) do
    GenServer.call(server, :next_activation_batch)
  end

  def clear_dead_letter(server \\ __MODULE__, entry_id, override_reason) do
    GenServer.call(server, {:clear_dead_letter, entry_id, override_reason})
  end

  def replace_dead_letter(server \\ __MODULE__, entry_id, replacement_entry, override_reason) do
    GenServer.call(server, {:replace_dead_letter, entry_id, replacement_entry, override_reason})
  end

  def retry_dead_letter_with_override(server \\ __MODULE__, entry_id, override_reason, opts \\ []) do
    GenServer.call(server, {:retry_dead_letter_with_override, entry_id, override_reason, opts})
  end

  def bulk_recover_dead_letters(server \\ __MODULE__, selector, operation) do
    GenServer.call(server, {:bulk_recover_dead_letters, selector, operation})
  end

  def quarantine_session(server \\ __MODULE__, session_id, reason_family, opts \\ []) do
    GenServer.call(server, {:quarantine_session, session_id, reason_family, opts})
  end

  def quarantined_sessions(server \\ __MODULE__) do
    GenServer.call(server, :quarantined_sessions)
  end

  def force_evict_quarantined(server \\ __MODULE__, session_id) do
    GenServer.call(server, {:force_evict_quarantined, session_id})
  end

  def inspect_session(server \\ __MODULE__, session_id) do
    GenServer.call(server, {:inspect_session, session_id})
  end

  @impl true
  def init(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    store_key = Keyword.get(opts, :store_key, {__MODULE__, name, :persistent_store})
    store = :persistent_term.get(store_key, default_store())

    {:ok,
     %{
       clock: Keyword.get(opts, :clock, SystemClock),
       kernel_snapshot: Keyword.get(opts, :kernel_snapshot, KernelSnapshot),
       flush_interval_ms: Keyword.get(opts, :flush_interval_ms, 10),
       activation_policy:
         Keyword.get(opts, :activation_policy, SessionActivationPolicy.new!(%{})),
       store_key: store_key,
       store: store,
       fault_injection: Keyword.get(opts, :fault_injection),
       pending_project_binding_epoch: nil,
       pending_updated_at: nil,
       flush_timer_ref: nil,
       activation_queue: %{}
     }}
  end

  @impl true
  def handle_call(:reset, _from, state) do
    store = default_store()
    state = persist_store(%{state | store: store, activation_queue: %{}})
    {:reply, :ok, state}
  end

  def handle_call({:configure_fault_injection, fault_injection}, _from, state) do
    {:reply, :ok, %{state | fault_injection: fault_injection}}
  end

  def handle_call({:seed_raw_blob, session_id, raw_blob}, _from, state) do
    state =
      state
      |> put_store_in([:blobs, session_id], raw_blob)
      |> maybe_refresh_cached_metadata(session_id)

    {:reply, :ok, state}
  end

  def handle_call({:fetch_persisted_blob, session_id}, _from, state) do
    reply =
      case Map.get(state.store.blobs, session_id) do
        nil -> {:ok, nil}
        raw_blob -> migrate_blob(raw_blob)
      end

    {:reply, reply, state}
  end

  def handle_call({:claim_session, session_id, opts}, _from, state) do
    now = state.clock.utc_now()

    case Map.get(state.store.blobs, session_id) do
      nil ->
        {state, claimed_blob} = build_new_claimed_blob(state, session_id, now, opts)

        emit_lifecycle_telemetry(:attached)
        {:reply, {:ok, %{blob: claimed_blob, lifecycle_event: :attached}}, state}

      raw_blob ->
        with {:ok, current_blob} <- migrate_blob(raw_blob) do
          claimed_blob =
            current_blob
            |> replace_envelope(%{
              continuity_revision: current_blob.envelope.continuity_revision + 1,
              owner_incarnation: current_blob.envelope.owner_incarnation + 1,
              last_active_at: now
            })

          state =
            state
            |> put_store_in([:blobs, session_id], claimed_blob)
            |> maybe_refresh_cached_metadata(session_id)

          emit_lifecycle_telemetry(:resumed)
          {:reply, {:ok, %{blob: claimed_blob, lifecycle_event: :resumed}}, state}
        else
          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call(:project_binding_epoch, _from, state) do
    {:reply, state.store.project_binding_epoch, state}
  end

  def handle_call({:commit_continuity, %SessionContinuityCommit{} = commit}, _from, state) do
    reply =
      with raw_blob when not is_nil(raw_blob) <- Map.get(state.store.blobs, commit.session_id),
           {:ok, current_blob} <- migrate_blob(raw_blob),
           :ok <- validate_commit_fence(current_blob, commit) do
        {state, applied_blob} =
          apply_commit_binding_epoch(state, current_blob, commit.persisted_blob)

        fault_result = fault_result(state.fault_injection, commit)

        case fault_result do
          :ok ->
            state =
              state
              |> put_store_in([:blobs, commit.session_id], applied_blob)
              |> maybe_refresh_cached_metadata(commit.session_id)

            {{:ok, applied_blob}, state}

          {:error, :acknowledgement_missing} ->
            {{:error, :acknowledgement_missing}, state}

          {:error, :acknowledgement_ambiguous, :committed} ->
            state =
              state
              |> put_store_in([:blobs, commit.session_id], applied_blob)
              |> maybe_refresh_cached_metadata(commit.session_id)

            {{:error, :acknowledgement_ambiguous}, state}

          {:error, :acknowledgement_ambiguous, :not_committed} ->
            {{:error, :acknowledgement_ambiguous}, state}
        end
      else
        nil ->
          {{:error, :session_missing}, state}

        {:error, reason} ->
          {{:error, reason}, state}
      end

    {response, state} = reply
    {:reply, response, state}
  end

  def handle_call({:resolve_outbox_entry, entry_id}, _from, state) do
    reply =
      Enum.find_value(state.store.blobs, {:error, :not_found}, fn {session_id, raw_blob} ->
        case migrate_blob(raw_blob) do
          {:ok, blob} ->
            case Map.get(blob.outbox_entries, entry_id) do
              nil -> false
              entry -> {:ok, %{session_id: session_id, entry: entry}}
            end

          {:error, _reason} ->
            false
        end
      end)

    {:reply, reply, state}
  end

  def handle_call({:register_active_session, session_id, opts}, _from, state) do
    cursor_info = %{
      session_id: session_id,
      committed_signal_cursor: Keyword.get(opts, :committed_signal_cursor),
      priority_class: Keyword.get(opts, :priority_class, "background"),
      pending_replay_safe: Keyword.get(opts, :pending_replay_safe, false),
      live_request: Keyword.get(opts, :live_request, false),
      registered_at: state.clock.utc_now()
    }

    state = put_store_in(state, [:active_sessions, session_id], cursor_info)
    {:reply, :ok, state}
  end

  def handle_call({:unregister_active_session, session_id}, _from, state) do
    state =
      put_store_in(state, [:active_sessions], Map.delete(state.store.active_sessions, session_id))

    {:reply, :ok, state}
  end

  def handle_call(:list_active_session_cursors, _from, state) do
    {:reply, Map.values(state.store.active_sessions), state}
  end

  def handle_call({:batch_load_committed_cursors, session_ids}, _from, state) do
    result =
      Map.take(state.store.active_sessions, session_ids)
      |> Map.new(fn {session_id, cursor_info} -> {session_id, cursor_info} end)

    {:reply, result, state}
  end

  def handle_call({:enqueue_activation, session_id, priority_class}, _from, state) do
    activation_queue =
      Map.put(state.activation_queue, session_id, %{
        priority_class: priority_class,
        queued_at: state.clock.utc_now()
      })

    emit_activation_backlog_telemetry(activation_queue, state.activation_policy)
    {:reply, :ok, %{state | activation_queue: activation_queue}}
  end

  def handle_call(:next_activation_batch, _from, state) do
    ordered =
      state.activation_queue
      |> Enum.sort_by(fn {_session_id, item} ->
        {SessionActivationPolicy.priority_rank(state.activation_policy, item.priority_class),
         item.queued_at}
      end)

    {selected, remaining} =
      Enum.split(ordered, state.activation_policy.max_concurrent_activations)

    state = %{state | activation_queue: Map.new(remaining)}

    Enum.each(selected, fn {_session_id, item} ->
      latency_ms = DateTime.diff(state.clock.utc_now(), item.queued_at, :millisecond)

      :telemetry.execute(
        Telemetry.event_name(:cold_boot_activation),
        %{backlog: map_size(state.activation_queue), latency_ms: max(latency_ms, 0)},
        %{priority_class: item.priority_class}
      )
    end)

    {:reply,
     Enum.map(selected, fn {session_id, item} ->
       %{session_id: session_id, priority_class: item.priority_class, queued_at: item.queued_at}
     end), state}
  end

  def handle_call({:clear_dead_letter, entry_id, override_reason}, _from, state) do
    {reply, state} =
      mutate_dead_letter_entry(state, entry_id, fn blob, _entry ->
        outbox = PersistedSessionBlob.restore_session_outbox!(blob)
        updated_outbox = SessionOutbox.delete_entry!(outbox, entry_id)

        rebuild_blob_from_outbox(blob, updated_outbox, %{
          "dead_letter_maintenance" => %{
            "entry_id" => entry_id,
            "operation" => "clear",
            "override_reason" => override_reason
          }
        })
      end)

    {:reply, reply, state}
  end

  def handle_call(
        {:replace_dead_letter, entry_id, replacement_entry, override_reason},
        _from,
        state
      ) do
    {reply, state} =
      mutate_dead_letter_entry(state, entry_id, fn blob, _entry ->
        outbox =
          blob
          |> PersistedSessionBlob.restore_session_outbox!()
          |> SessionOutbox.delete_entry!(entry_id)
          |> SessionOutbox.put_entry!(replacement_entry)

        rebuild_blob_from_outbox(blob, outbox, %{
          "dead_letter_maintenance" => %{
            "entry_id" => entry_id,
            "operation" => "replace",
            "override_reason" => override_reason
          }
        })
      end)

    {:reply, reply, state}
  end

  def handle_call(
        {:retry_dead_letter_with_override, entry_id, override_reason, opts},
        _from,
        state
      ) do
    next_attempt_at = Keyword.get(opts, :next_attempt_at, state.clock.utc_now())

    {reply, state} =
      mutate_dead_letter_entry(state, entry_id, fn blob, entry ->
        retried_entry =
          ActionOutboxEntry.new!(%{
            ActionOutboxEntry.dump(entry)
            | replay_status: :pending,
              next_attempt_at: next_attempt_at,
              dead_letter_reason: nil,
              last_error_code: nil,
              extensions:
                Map.merge(entry.extensions, %{
                  "override_reason" => override_reason,
                  "override_retried_at" => DateTime.to_iso8601(state.clock.utc_now())
                })
          })

        outbox =
          blob
          |> PersistedSessionBlob.restore_session_outbox!()
          |> SessionOutbox.put_entry!(retried_entry)

        rebuild_blob_from_outbox(blob, outbox, %{
          "dead_letter_maintenance" => %{
            "entry_id" => entry_id,
            "operation" => "retry_with_override",
            "override_reason" => override_reason
          }
        })
      end)

    {:reply, reply, state}
  end

  def handle_call({:bulk_recover_dead_letters, selector, operation}, _from, state) do
    {state, affected_entry_count} =
      Enum.reduce(state.store.blobs, {state, 0}, fn {_session_id, raw_blob},
                                                    {state_acc, count_acc} ->
        case migrate_blob(raw_blob) do
          {:ok, blob} ->
            dead_letter_entries =
              blob.outbox_entries
              |> Map.values()
              |> Enum.filter(fn entry ->
                entry.replay_status == :dead_letter and
                  match_dead_letter_selector?(entry, selector)
              end)

            {state_acc, updated_count} =
              Enum.reduce(dead_letter_entries, {state_acc, count_acc}, fn entry,
                                                                          {state_inner,
                                                                           inner_count} ->
                case apply_bulk_recovery_operation(state_inner, entry.entry_id, operation) do
                  {:ok, next_state} -> {next_state, inner_count + 1}
                  {:error, _reason} -> {next_state_or_self(state_inner), inner_count}
                end
              end)

            {state_acc, updated_count}

          {:error, _reason} ->
            {state_acc, count_acc}
        end
      end)

    :telemetry.execute(
      Telemetry.event_name(:dead_letter_bulk_recovery),
      %{operation_count: 1, affected_entry_count: affected_entry_count},
      %{}
    )

    {:reply, {:ok, affected_entry_count}, state}
  end

  def handle_call({:quarantine_session, session_id, reason_family, opts}, _from, state) do
    eviction_deadline =
      Keyword.get_lazy(opts, :eviction_deadline, fn ->
        DateTime.add(state.clock.utc_now(), 7 * 24 * 60 * 60, :second)
      end)

    raw_blob = Map.get(state.store.blobs, session_id)

    state =
      case raw_blob && migrate_blob(raw_blob) do
        {:ok, blob} ->
          quarantined_blob =
            blob
            |> replace_envelope(%{
              lifecycle_status: :quarantined,
              last_active_at: state.clock.utc_now()
            })
            |> put_envelope_extensions(%{
              "quarantine" => %{
                "reason_family" => reason_family,
                "eviction_deadline" => DateTime.to_iso8601(eviction_deadline)
              }
            })

          state
          |> put_store_in([:blobs, session_id], quarantined_blob)
          |> put_store_in([:quarantine, session_id], %{
            reason_family: reason_family,
            eviction_deadline: eviction_deadline
          })
          |> maybe_refresh_cached_metadata(session_id)

        _ ->
          state
          |> put_store_in([:quarantine, session_id], %{
            reason_family: reason_family,
            eviction_deadline: eviction_deadline
          })
      end

    :telemetry.execute(
      Telemetry.event_name(:quarantined_session_count),
      %{count: map_size(state.store.quarantine)},
      %{}
    )

    {:reply, :ok, state}
  end

  def handle_call(:quarantined_sessions, _from, state) do
    {:reply, state.store.quarantine, state}
  end

  def handle_call({:force_evict_quarantined, session_id}, _from, state) do
    if Map.has_key?(state.store.quarantine, session_id) do
      state =
        state
        |> put_store_in([:quarantine], Map.delete(state.store.quarantine, session_id))
        |> put_store_in([:blobs], Map.delete(state.store.blobs, session_id))
        |> put_store_in([:active_sessions], Map.delete(state.store.active_sessions, session_id))
        |> put_store_in([:blocked_sessions], Map.delete(state.store.blocked_sessions, session_id))

      emit_lifecycle_telemetry(:evicted)
      {:reply, :ok, state}
    else
      {:reply, {:error, :not_quarantined}, state}
    end
  end

  def handle_call({:inspect_session, session_id}, _from, state) do
    reply = %{
      raw_blob: Map.get(state.store.blobs, session_id),
      blocked_entries: Map.get(state.store.blocked_sessions, session_id, %{}),
      quarantine: Map.get(state.store.quarantine, session_id),
      active_session: Map.get(state.store.active_sessions, session_id)
    }

    {:reply, reply, state}
  end

  @impl true
  def handle_info(@flush_message, %{pending_project_binding_epoch: nil} = state) do
    {:noreply, %{state | flush_timer_ref: nil}}
  end

  def handle_info(@flush_message, state) do
    KernelSnapshot.publish_epoch_update(
      state.kernel_snapshot,
      KernelEpochUpdate.new!(%{
        source_owner: Atom.to_string(__MODULE__),
        constituent: :project_binding_epoch,
        epoch: state.pending_project_binding_epoch,
        updated_at: state.pending_updated_at,
        extensions: %{}
      })
    )

    {:noreply,
     %{
       state
       | pending_project_binding_epoch: nil,
         pending_updated_at: nil,
         flush_timer_ref: nil
     }}
  end

  defp build_new_claimed_blob(state, session_id, now, opts) do
    {state, project_binding} =
      maybe_assign_claim_binding_epoch(state, Keyword.get(opts, :project_binding))

    blob =
      PersistedSessionBlob.new!(%{
        schema_version: 1,
        session_id: session_id,
        envelope:
          PersistedSessionEnvelope.new!(%{
            schema_version: 1,
            session_id: session_id,
            continuity_revision: 1,
            owner_incarnation: 1,
            project_binding: project_binding,
            scope_ref: Keyword.get(opts, :scope_ref),
            signal_cursor: Keyword.get(opts, :signal_cursor),
            recent_signal_hashes: Keyword.get(opts, :recent_signal_hashes, []),
            lifecycle_status: Keyword.get(opts, :lifecycle_status, :active),
            last_active_at: now,
            active_plan: nil,
            active_authority_decision: nil,
            last_rejection: nil,
            boundary_ref: Keyword.get(opts, :boundary_ref),
            outbox_entry_ids: [],
            external_refs: Keyword.get(opts, :external_refs, %{}),
            extensions: Keyword.get(opts, :extensions, %{})
          }),
        outbox_entries: %{},
        extensions: %{}
      })

    state =
      state
      |> put_store_in([:blobs, session_id], blob)
      |> maybe_refresh_cached_metadata(session_id)

    {state, blob}
  end

  defp maybe_assign_claim_binding_epoch(state, nil), do: {state, nil}

  defp maybe_assign_claim_binding_epoch(state, %ProjectBinding{} = project_binding) do
    next_epoch = state.store.project_binding_epoch + 1

    assigned_binding =
      project_binding
      |> ProjectBinding.dump()
      |> Map.put(:binding_epoch, next_epoch)
      |> ProjectBinding.new!()

    state =
      state
      |> put_store_in([:project_binding_epoch], next_epoch)
      |> schedule_project_binding_flush(next_epoch)

    {state, assigned_binding}
  end

  defp validate_commit_fence(current_blob, commit) do
    cond do
      current_blob.envelope.continuity_revision != commit.expected_continuity_revision ->
        {:error, :stale_continuity_revision}

      current_blob.envelope.owner_incarnation != commit.expected_owner_incarnation ->
        {:error, :stale_owner_incarnation}

      true ->
        :ok
    end
  end

  defp apply_commit_binding_epoch(state, current_blob, next_blob) do
    current_binding = current_blob.envelope.project_binding
    next_binding = next_blob.envelope.project_binding

    cond do
      binding_identity(current_binding) == binding_identity(next_binding) ->
        next_blob =
          case {current_binding, next_binding} do
            {%ProjectBinding{} = current, %ProjectBinding{} = proposed} ->
              normalize_binding_epoch(next_blob, current.binding_epoch, proposed)

            _ ->
              next_blob
          end

        {state, next_blob}

      true ->
        next_epoch = state.store.project_binding_epoch + 1

        next_blob =
          case next_binding do
            %ProjectBinding{} = proposed ->
              normalize_binding_epoch(next_blob, next_epoch, proposed)

            nil ->
              next_blob
          end

        state =
          state
          |> put_store_in([:project_binding_epoch], next_epoch)
          |> schedule_project_binding_flush(next_epoch)

        {state, next_blob}
    end
  end

  defp normalize_binding_epoch(next_blob, binding_epoch, proposed_binding) do
    normalized_binding =
      proposed_binding
      |> ProjectBinding.dump()
      |> Map.put(:binding_epoch, binding_epoch)
      |> ProjectBinding.new!()

    replace_envelope(next_blob, %{project_binding: normalized_binding})
  end

  defp fault_result(nil, _commit), do: :ok

  defp fault_result(fault_injection, commit) when is_function(fault_injection, 1),
    do: fault_injection.(commit)

  defp mutate_dead_letter_entry(state, entry_id, mutation_fun) do
    with {:ok, %{session_id: session_id, entry: entry}} <-
           resolve_entry_from_store(state, entry_id),
         true <- entry.replay_status == :dead_letter or {:error, :not_dead_letter},
         {:ok, current_blob} <- fetch_blob_from_store(state, session_id) do
      updated_blob = mutation_fun.(current_blob, entry)

      state =
        state
        |> put_store_in([:blobs, session_id], updated_blob)
        |> maybe_refresh_cached_metadata(session_id)

      {{:ok, updated_blob}, state}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  defp resolve_entry_from_store(state, entry_id) do
    Enum.find_value(state.store.blobs, {:error, :not_found}, fn {session_id, raw_blob} ->
      case migrate_blob(raw_blob) do
        {:ok, blob} ->
          case Map.get(blob.outbox_entries, entry_id) do
            nil -> false
            entry -> {:ok, %{session_id: session_id, entry: entry}}
          end

        {:error, _reason} ->
          false
      end
    end)
  end

  defp fetch_blob_from_store(state, session_id) do
    case Map.get(state.store.blobs, session_id) do
      nil -> {:error, :session_missing}
      raw_blob -> migrate_blob(raw_blob)
    end
  end

  defp rebuild_blob_from_outbox(blob, %SessionOutbox{} = outbox, extensions_patch) do
    updated_extensions =
      blob.envelope.extensions
      |> Map.merge(extensions_patch)

    updated_envelope =
      blob.envelope
      |> PersistedSessionEnvelope.dump()
      |> Map.put(:outbox_entry_ids, outbox.entry_order)
      |> Map.put(:extensions, updated_extensions)
      |> PersistedSessionEnvelope.new!()

    PersistedSessionBlob.new!(%{
      schema_version: 1,
      session_id: blob.session_id,
      envelope: updated_envelope,
      outbox_entries: outbox.entries_by_id,
      extensions: blob.extensions
    })
  end

  defp apply_bulk_recovery_operation(state, entry_id, {:clear, override_reason}) do
    case apply_clear_dead_letter(state, entry_id, override_reason) do
      {:ok, next_state} -> {:ok, next_state}
      other -> other
    end
  end

  defp apply_bulk_recovery_operation(state, entry_id, {:retry_with_override, override_reason}) do
    case apply_retry_dead_letter_with_override(state, entry_id, override_reason) do
      {:ok, next_state} -> {:ok, next_state}
      other -> other
    end
  end

  defp apply_bulk_recovery_operation(
         state,
         entry_id,
         {:replace, replacement_builder, override_reason}
       )
       when is_function(replacement_builder, 1) do
    with {:ok, %{entry: entry}} <- resolve_entry_from_store(state, entry_id),
         replacement_entry <- replacement_builder.(entry),
         {:ok, next_state} <-
           apply_replace_dead_letter(state, entry_id, replacement_entry, override_reason) do
      {:ok, next_state}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp apply_bulk_recovery_operation(_state, _entry_id, _operation),
    do: {:error, :unsupported_operation}

  defp apply_clear_dead_letter(state, entry_id, override_reason) do
    case mutate_dead_letter_entry(state, entry_id, fn blob, _entry ->
           outbox = PersistedSessionBlob.restore_session_outbox!(blob)
           updated_outbox = SessionOutbox.delete_entry!(outbox, entry_id)

           rebuild_blob_from_outbox(blob, updated_outbox, %{
             "dead_letter_maintenance" => %{
               "entry_id" => entry_id,
               "operation" => "clear",
               "override_reason" => override_reason
             }
           })
         end) do
      {{:ok, _blob}, next_state} -> {:ok, next_state}
      {{:error, reason}, _state} -> {:error, reason}
    end
  end

  defp apply_replace_dead_letter(state, entry_id, replacement_entry, override_reason) do
    case mutate_dead_letter_entry(state, entry_id, fn blob, _entry ->
           outbox =
             blob
             |> PersistedSessionBlob.restore_session_outbox!()
             |> SessionOutbox.delete_entry!(entry_id)
             |> SessionOutbox.put_entry!(replacement_entry)

           rebuild_blob_from_outbox(blob, outbox, %{
             "dead_letter_maintenance" => %{
               "entry_id" => entry_id,
               "operation" => "replace",
               "override_reason" => override_reason
             }
           })
         end) do
      {{:ok, _blob}, next_state} -> {:ok, next_state}
      {{:error, reason}, _state} -> {:error, reason}
    end
  end

  defp apply_retry_dead_letter_with_override(state, entry_id, override_reason) do
    case mutate_dead_letter_entry(state, entry_id, fn blob, entry ->
           retried_entry =
             ActionOutboxEntry.new!(%{
               ActionOutboxEntry.dump(entry)
               | replay_status: :pending,
                 next_attempt_at: state.clock.utc_now(),
                 dead_letter_reason: nil,
                 last_error_code: nil,
                 extensions:
                   Map.merge(entry.extensions, %{
                     "override_reason" => override_reason,
                     "override_retried_at" => DateTime.to_iso8601(state.clock.utc_now())
                   })
             })

           outbox =
             blob
             |> PersistedSessionBlob.restore_session_outbox!()
             |> SessionOutbox.put_entry!(retried_entry)

           rebuild_blob_from_outbox(blob, outbox, %{
             "dead_letter_maintenance" => %{
               "entry_id" => entry_id,
               "operation" => "retry_with_override",
               "override_reason" => override_reason
             }
           })
         end) do
      {{:ok, _blob}, next_state} -> {:ok, next_state}
      {{:error, reason}, _state} -> {:error, reason}
    end
  end

  defp match_dead_letter_selector?(entry, selector) do
    Enum.all?(selector, fn
      {:action_kind, value} -> entry.action.action_kind == value
      {:dead_letter_reason, value} -> entry.dead_letter_reason == value
      {:last_error_code, value} -> entry.last_error_code == value
      {:ordering_mode, value} -> entry.ordering_mode == value
      {:schema_version, value} -> entry.schema_version == value
      _ -> true
    end)
  end

  defp maybe_refresh_cached_metadata(state, session_id) do
    raw_blob = Map.get(state.store.blobs, session_id)

    case raw_blob && migrate_blob(raw_blob) do
      {:ok, blob} ->
        blocked_entries = extract_blocked_entries(blob)

        state =
          if blocked_entries == %{} do
            put_store_in(
              state,
              [:blocked_sessions],
              Map.delete(state.store.blocked_sessions, session_id)
            )
          else
            emit_blocked_telemetry(blocked_entries)
            put_store_in(state, [:blocked_sessions, session_id], blocked_entries)
          end

        if blob.envelope.lifecycle_status == :quarantined do
          quarantine_meta =
            blob.envelope.extensions
            |> Map.get("quarantine", %{})
            |> normalize_quarantine_meta()

          put_store_in(state, [:quarantine, session_id], quarantine_meta)
        else
          put_store_in(state, [:quarantine], Map.delete(state.store.quarantine, session_id))
        end

      _ ->
        state
    end
  end

  defp extract_blocked_entries(blob) do
    blob.outbox_entries
    |> Map.values()
    |> Enum.filter(fn entry ->
      entry.replay_status == :dead_letter and entry.ordering_mode == :strict
    end)
    |> Map.new(fn entry ->
      {entry.entry_id,
       %{
         entry_id: entry.entry_id,
         reason_family: entry.dead_letter_reason || "unknown",
         last_error_code: entry.last_error_code
       }}
    end)
  end

  defp normalize_quarantine_meta(%{
         "reason_family" => reason_family,
         "eviction_deadline" => eviction_deadline
       }) do
    %{
      reason_family: reason_family,
      eviction_deadline: DateTime.from_iso8601(eviction_deadline) |> elem(1)
    }
  end

  defp normalize_quarantine_meta(_meta) do
    %{
      reason_family: "unknown",
      eviction_deadline: DateTime.add(DateTime.utc_now(), 7 * 24 * 60 * 60, :second)
    }
  end

  defp replace_envelope(%PersistedSessionBlob{} = blob, updates) do
    updated_envelope =
      blob.envelope
      |> PersistedSessionEnvelope.dump()
      |> Map.merge(Map.new(updates))
      |> PersistedSessionEnvelope.new!()

    PersistedSessionBlob.new!(%{
      schema_version: blob.schema_version,
      session_id: blob.session_id,
      envelope: updated_envelope,
      outbox_entries: blob.outbox_entries,
      extensions: blob.extensions
    })
  end

  defp put_envelope_extensions(%PersistedSessionBlob{} = blob, patch) do
    replace_envelope(blob, %{extensions: Map.merge(blob.envelope.extensions, patch)})
  end

  defp binding_identity(nil), do: nil

  defp binding_identity(%ProjectBinding{} = binding) do
    {binding.binding_id, binding.project_id, binding.workspace_root}
  end

  defp migrate_blob(raw_blob) do
    {:ok, SessionMigration.migrate_blob!(raw_blob)}
  rescue
    error in ArgumentError -> {:error, {:migration_failed, error.message}}
  end

  defp put_store_in(state, path, value) do
    updated_store = put_in(state.store, path, value)
    persist_store(%{state | store: updated_store})
  end

  defp persist_store(%{store_key: store_key, store: store} = state) do
    :persistent_term.put(store_key, store)
    state
  end

  defp schedule_project_binding_flush(%{flush_timer_ref: nil} = state, next_epoch) do
    %{
      state
      | pending_project_binding_epoch: next_epoch,
        pending_updated_at: state.clock.utc_now(),
        flush_timer_ref: Process.send_after(self(), @flush_message, state.flush_interval_ms)
    }
  end

  defp schedule_project_binding_flush(state, next_epoch) do
    %{
      state
      | pending_project_binding_epoch: next_epoch,
        pending_updated_at: state.clock.utc_now()
    }
  end

  defp emit_lifecycle_telemetry(lifecycle_event) do
    :telemetry.execute(
      Telemetry.event_name(:session_lifecycle_count),
      %{count: 1},
      %{lifecycle_event: lifecycle_event}
    )
  end

  defp emit_blocked_telemetry(blocked_entries) do
    Enum.each(blocked_entries, fn {_entry_id, entry} ->
      :telemetry.execute(
        Telemetry.event_name(:blocked_session_count),
        %{count: 1},
        %{reason_family: entry.reason_family}
      )

      :telemetry.execute(
        Telemetry.event_name(:blocked_session_alert_count),
        %{count: 1},
        %{strict_dead_letter_family: entry.reason_family}
      )
    end)
  end

  defp emit_activation_backlog_telemetry(activation_queue, activation_policy) do
    activation_queue
    |> Map.values()
    |> Enum.group_by(& &1.priority_class)
    |> Enum.each(fn {priority_class, entries} ->
      :telemetry.execute(
        Telemetry.event_name(:cold_boot_activation),
        %{backlog: length(entries), latency_ms: 0},
        %{priority_class: priority_class}
      )
    end)

    activation_policy
  end

  defp default_store do
    %{
      blobs: %{},
      active_sessions: %{},
      project_binding_epoch: 0,
      quarantine: %{},
      blocked_sessions: %{}
    }
  end

  defp next_state_or_self(state), do: state
end
