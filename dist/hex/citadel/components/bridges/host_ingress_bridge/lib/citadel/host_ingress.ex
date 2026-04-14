defmodule Citadel.HostIngress do
  @moduledoc """
  Public structured host-ingress seam above Citadel's runtime and lower bridge.
  """

  alias Citadel.DecisionRejection
  alias Citadel.HostIngress.Accepted
  alias Citadel.HostIngress.InvocationCompiler
  alias Citadel.HostIngress.RequestContext
  alias Citadel.IntentEnvelope
  alias Citadel.PersistedSessionBlob
  alias Citadel.PersistedSessionEnvelope
  alias Citadel.Runtime
  alias Citadel.Runtime.SessionDirectory
  alias Citadel.Runtime.SessionServer
  alias Citadel.Runtime.SystemClock
  alias Citadel.ScopeRef
  alias Citadel.SessionContinuityCommit
  alias Citadel.SessionOutbox

  @manifest %{
    package: :citadel_host_ingress_bridge,
    layer: :bridge,
    status: :public_structured_ingress_frozen,
    owns: [
      :public_host_ingress_surface,
      :structured_ingress_compilation,
      :durable_invocation_enqueue
    ],
    internal_dependencies: [
      :citadel_core,
      :citadel_runtime,
      :citadel_authority_contract,
      :citadel_execution_governance_contract,
      :citadel_policy_packs
    ],
    external_dependencies: []
  }

  @type t :: %__MODULE__{
          session_directory: GenServer.server(),
          policy_packs: [map()],
          lookup_session: (String.t() -> {:ok, pid()} | {:error, term()}),
          clock: module()
        }

  @type submission_result ::
          {:accepted, Accepted.t()}
          | {:rejected, DecisionRejection.t()}
          | {:error, term()}

  defstruct session_directory: SessionDirectory,
            policy_packs: [],
            lookup_session: &Runtime.lookup_session/1,
            clock: SystemClock

  @spec manifest() :: map()
  def manifest, do: @manifest

  @spec new!(keyword()) :: t()
  def new!(opts) do
    lookup_session = Keyword.get(opts, :lookup_session, &Runtime.lookup_session/1)
    clock = Keyword.get(opts, :clock, SystemClock)

    unless is_function(lookup_session, 1) do
      raise ArgumentError, "host_ingress lookup_session must be an arity-1 function"
    end

    unless is_atom(clock) and function_exported?(clock, :utc_now, 0) do
      raise ArgumentError, "host_ingress clock must export utc_now/0"
    end

    %__MODULE__{
      session_directory: Keyword.get(opts, :session_directory, SessionDirectory),
      policy_packs: Keyword.get(opts, :policy_packs, []),
      lookup_session: lookup_session,
      clock: clock
    }
  end

  @spec submit_envelope(
          t(),
          IntentEnvelope.t() | map() | keyword(),
          RequestContext.t() | map() | keyword(),
          keyword()
        ) ::
          submission_result()
  def submit_envelope(%__MODULE__{} = ingress, envelope, request_context, opts \\ []) do
    request_context = RequestContext.new!(request_context)

    case InvocationCompiler.compile(envelope, request_context, ingress.policy_packs, opts) do
      {:ok, compiled} ->
        persist_compiled_invocation(ingress, request_context, compiled, opts)

      {:rejected, %DecisionRejection{} = rejection} ->
        case persist_rejection(ingress, request_context, rejection, opts) do
          :ok -> {:rejected, rejection}
          {:error, reason} -> {:error, reason}
        end

      {:error, %ArgumentError{} = error} ->
        {:error, {:invalid_ingress, Exception.message(error)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp persist_compiled_invocation(ingress, request_context, compiled, opts) do
    claim_opts = claim_opts(request_context, compiled.scope_ref)

    case ingress.lookup_session.(request_context.session_id) do
      {:ok, session_server} ->
        persist_with_live_owner(session_server, request_context, compiled, claim_opts)

      {:error, :not_found} ->
        persist_without_live_owner(ingress, request_context, compiled, claim_opts, opts)

      {:error, reason} ->
        {:error, reason}
    end
  catch
    :exit, {:noproc, _details} ->
      persist_without_live_owner(
        ingress,
        request_context,
        compiled,
        claim_opts(request_context, compiled.scope_ref),
        opts
      )

    :exit, :noproc ->
      persist_without_live_owner(
        ingress,
        request_context,
        compiled,
        claim_opts(request_context, compiled.scope_ref),
        opts
      )
  end

  defp persist_with_live_owner(session_server, request_context, compiled, _claim_opts) do
    session_state = SessionServer.snapshot(session_server)

    case Map.get(session_state.outbox.entries_by_id, compiled.entry_id) do
      nil ->
        updated_outbox = SessionOutbox.put_entry!(session_state.outbox, compiled.outbox_entry)

        case SessionServer.commit_transition(
               session_server,
               %{outbox: updated_outbox},
               meaningful_activity?: true
             ) do
          {:ok, next_state} ->
            {:accepted,
             Accepted.new!(%{
               request_id: request_context.request_id,
               session_id: request_context.session_id,
               trace_id: request_context.trace_id,
               ingress_path: :direct_intent_envelope,
               lifecycle_event: :live_owner,
               continuity_revision: next_state.continuity_revision,
               entry_id: compiled.entry_id,
               metadata: %{submission_status: :queued}
             })}

          {:error, reason} ->
            {:error, reason}
        end

      _existing_entry ->
        {:accepted,
         Accepted.new!(%{
           request_id: request_context.request_id,
           session_id: request_context.session_id,
           trace_id: request_context.trace_id,
           ingress_path: :direct_intent_envelope,
           lifecycle_event: :live_owner,
           continuity_revision: session_state.continuity_revision,
           entry_id: compiled.entry_id,
           metadata: %{submission_status: :already_present}
         })}
    end
  end

  defp persist_without_live_owner(ingress, request_context, compiled, claim_opts, opts) do
    priority_class = Keyword.get(opts, :activation_priority_class, "live_request")

    with {:ok, %{blob: claimed_blob, lifecycle_event: lifecycle_event}} <-
           SessionDirectory.claim_session(
             ingress.session_directory,
             request_context.session_id,
             claim_opts
           ),
         {:ok, committed_blob, inserted?} <-
           commit_outbox_without_live_owner(ingress, claimed_blob, compiled.outbox_entry),
         :ok <-
           maybe_enqueue_activation(
             ingress.session_directory,
             request_context.session_id,
             inserted?,
             priority_class
           ) do
      {:accepted,
       Accepted.new!(%{
         request_id: request_context.request_id,
         session_id: request_context.session_id,
         trace_id: request_context.trace_id,
         ingress_path: :direct_intent_envelope,
         lifecycle_event: lifecycle_event,
         continuity_revision: committed_blob.envelope.continuity_revision,
         entry_id: compiled.entry_id,
         metadata: %{submission_status: inserted_submission_status(inserted?)}
       })}
    end
  end

  defp persist_rejection(ingress, request_context, rejection, opts) do
    claim_opts = claim_opts(request_context, Keyword.get(opts, :scope_ref, nil))

    case ingress.lookup_session.(request_context.session_id) do
      {:ok, session_server} ->
        case record_rejection_with_live_owner(session_server, rejection) do
          {:ok, _session_state} ->
            :ok

          {:error, :not_found} ->
            persist_rejection_without_live_owner(
              ingress,
              request_context.session_id,
              rejection,
              claim_opts
            )

          {:error, reason} ->
            {:error, reason}
        end

      {:error, :not_found} ->
        persist_rejection_without_live_owner(
          ingress,
          request_context.session_id,
          rejection,
          claim_opts
        )

      {:error, reason} ->
        {:error, reason}
    end
  catch
    :exit, {:noproc, _details} ->
      persist_rejection_without_live_owner(
        ingress,
        request_context.session_id,
        rejection,
        claim_opts(request_context, Keyword.get(opts, :scope_ref, nil))
      )

    :exit, :noproc ->
      persist_rejection_without_live_owner(
        ingress,
        request_context.session_id,
        rejection,
        claim_opts(request_context, Keyword.get(opts, :scope_ref, nil))
      )
  end

  defp persist_rejection_without_live_owner(ingress, session_id, rejection, claim_opts) do
    with {:ok, %{blob: claimed_blob}} <-
           SessionDirectory.claim_session(ingress.session_directory, session_id, claim_opts),
         {:ok, _committed_blob} <- commit_rejection(ingress, claimed_blob, rejection) do
      :ok
    end
  end

  defp record_rejection_with_live_owner(session_server, rejection) do
    SessionServer.record_rejection(session_server, rejection)
  catch
    :exit, {:noproc, _details} -> {:error, :not_found}
    :exit, :noproc -> {:error, :not_found}
    :exit, reason -> {:error, reason}
  end

  defp commit_outbox_without_live_owner(
         ingress,
         %PersistedSessionBlob{} = claimed_blob,
         outbox_entry
       ) do
    outbox = PersistedSessionBlob.restore_session_outbox!(claimed_blob)

    case Map.get(outbox.entries_by_id, outbox_entry.entry_id) do
      nil ->
        updated_outbox = SessionOutbox.put_entry!(outbox, outbox_entry)

        commit_blob =
          rebuild_blob_from_outbox(claimed_blob, updated_outbox, ingress.clock.utc_now())

        case commit_continuity(ingress.session_directory, claimed_blob, commit_blob) do
          {:ok, committed_blob} -> {:ok, committed_blob, true}
          {:error, reason} -> {:error, reason}
        end

      _existing_entry ->
        {:ok, claimed_blob, false}
    end
  end

  defp maybe_enqueue_activation(_session_directory, _session_id, false, _priority_class), do: :ok

  defp maybe_enqueue_activation(session_directory, session_id, true, priority_class) do
    SessionDirectory.enqueue_activation(session_directory, session_id, priority_class)
  end

  defp inserted_submission_status(true), do: :queued
  defp inserted_submission_status(false), do: :already_present

  defp commit_rejection(
         ingress,
         %PersistedSessionBlob{} = claimed_blob,
         %DecisionRejection{} = rejection
       ) do
    next_blob =
      PersistedSessionBlob.new!(%{
        schema_version: PersistedSessionBlob.schema_version(),
        session_id: claimed_blob.session_id,
        envelope:
          claimed_blob.envelope
          |> PersistedSessionEnvelope.dump()
          |> Map.merge(%{
            continuity_revision: claimed_blob.envelope.continuity_revision + 1,
            last_active_at: ingress.clock.utc_now(),
            last_rejection: rejection
          })
          |> PersistedSessionEnvelope.new!(),
        outbox_entries: claimed_blob.outbox_entries,
        extensions: claimed_blob.extensions
      })

    commit_continuity(ingress.session_directory, claimed_blob, next_blob)
  end

  defp rebuild_blob_from_outbox(%PersistedSessionBlob{} = claimed_blob, updated_outbox, now) do
    PersistedSessionBlob.new!(%{
      schema_version: PersistedSessionBlob.schema_version(),
      session_id: claimed_blob.session_id,
      envelope:
        claimed_blob.envelope
        |> PersistedSessionEnvelope.dump()
        |> Map.merge(%{
          continuity_revision: claimed_blob.envelope.continuity_revision + 1,
          last_active_at: now,
          outbox_entry_ids: updated_outbox.entry_order
        })
        |> PersistedSessionEnvelope.new!(),
      outbox_entries: updated_outbox.entries_by_id,
      extensions: claimed_blob.extensions
    })
  end

  defp commit_continuity(
         session_directory,
         %PersistedSessionBlob{} = claimed_blob,
         %PersistedSessionBlob{} = next_blob
       ) do
    commit =
      SessionContinuityCommit.new!(%{
        session_id: claimed_blob.session_id,
        expected_continuity_revision: claimed_blob.envelope.continuity_revision,
        expected_owner_incarnation: claimed_blob.envelope.owner_incarnation,
        persisted_blob: next_blob,
        extensions: %{}
      })

    SessionDirectory.commit_continuity(session_directory, commit)
  end

  defp claim_opts(%RequestContext{} = request_context, %ScopeRef{} = scope_ref) do
    [
      scope_ref: scope_ref,
      extensions: host_extensions(request_context)
    ]
  end

  defp claim_opts(%RequestContext{} = request_context, nil) do
    [extensions: host_extensions(request_context)]
  end

  defp host_extensions(%RequestContext{} = request_context) do
    %{
      "host_ingress" => %{
        "request_id" => request_context.request_id,
        "trace_id" => request_context.trace_id,
        "trace_origin" => request_context.trace_origin
      }
    }
  end
end
