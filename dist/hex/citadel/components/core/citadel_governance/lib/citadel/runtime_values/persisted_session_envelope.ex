defmodule Citadel.PersistedSessionEnvelope do
  @moduledoc """
  Versioned durable session continuity envelope.
  """

  alias Citadel.AuthorityDecision
  alias Citadel.ContractCore.Value
  alias Citadel.DecisionRejection
  alias Citadel.Plan
  alias Citadel.ProjectBinding
  alias Citadel.ScopeRef
  alias Citadel.SessionState

  @schema_version 1
  @fields [
    :schema_version,
    :session_id,
    :continuity_revision,
    :owner_incarnation,
    :project_binding,
    :scope_ref,
    :signal_cursor,
    :recent_signal_hashes,
    :lifecycle_status,
    :last_active_at,
    :active_plan,
    :active_authority_decision,
    :last_rejection,
    :boundary_ref,
    :outbox_entry_ids,
    :external_refs,
    :extensions
  ]

  @type t :: %__MODULE__{
          schema_version: pos_integer(),
          session_id: String.t(),
          continuity_revision: non_neg_integer(),
          owner_incarnation: pos_integer(),
          project_binding: ProjectBinding.t() | nil,
          scope_ref: ScopeRef.t() | nil,
          signal_cursor: String.t() | nil,
          recent_signal_hashes: [String.t()],
          lifecycle_status: SessionState.lifecycle_status(),
          last_active_at: DateTime.t() | nil,
          active_plan: Plan.t() | nil,
          active_authority_decision: AuthorityDecision.t() | nil,
          last_rejection: DecisionRejection.t() | nil,
          boundary_ref: String.t() | nil,
          outbox_entry_ids: [String.t()],
          external_refs: map(),
          extensions: map()
        }

  @enforce_keys [
    :schema_version,
    :session_id,
    :continuity_revision,
    :owner_incarnation,
    :lifecycle_status,
    :outbox_entry_ids
  ]
  defstruct schema_version: @schema_version,
            session_id: nil,
            continuity_revision: 0,
            owner_incarnation: 1,
            project_binding: nil,
            scope_ref: nil,
            signal_cursor: nil,
            recent_signal_hashes: [],
            lifecycle_status: :active,
            last_active_at: nil,
            active_plan: nil,
            active_authority_decision: nil,
            last_rejection: nil,
            boundary_ref: nil,
            outbox_entry_ids: [],
            external_refs: %{},
            extensions: %{}

  def schema_version, do: @schema_version

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.PersistedSessionEnvelope", @fields)

    %__MODULE__{
      schema_version:
        Value.required(attrs, :schema_version, "Citadel.PersistedSessionEnvelope", fn value ->
          if value == @schema_version do
            value
          else
            raise ArgumentError,
                  "Citadel.PersistedSessionEnvelope.schema_version must be #{@schema_version}, got: #{inspect(value)}"
          end
        end),
      session_id:
        Value.required(attrs, :session_id, "Citadel.PersistedSessionEnvelope", fn value ->
          Value.string!(value, "Citadel.PersistedSessionEnvelope.session_id")
        end),
      continuity_revision:
        Value.required(
          attrs,
          :continuity_revision,
          "Citadel.PersistedSessionEnvelope",
          fn value ->
            Value.non_neg_integer!(value, "Citadel.PersistedSessionEnvelope.continuity_revision")
          end
        ),
      owner_incarnation:
        Value.required(attrs, :owner_incarnation, "Citadel.PersistedSessionEnvelope", fn value ->
          Value.positive_integer!(value, "Citadel.PersistedSessionEnvelope.owner_incarnation")
        end),
      project_binding:
        Value.optional(
          attrs,
          :project_binding,
          "Citadel.PersistedSessionEnvelope",
          fn value ->
            Value.module!(
              value,
              ProjectBinding,
              "Citadel.PersistedSessionEnvelope.project_binding"
            )
          end,
          nil
        ),
      scope_ref:
        Value.optional(
          attrs,
          :scope_ref,
          "Citadel.PersistedSessionEnvelope",
          fn value ->
            Value.module!(value, ScopeRef, "Citadel.PersistedSessionEnvelope.scope_ref")
          end,
          nil
        ),
      signal_cursor:
        Value.optional(
          attrs,
          :signal_cursor,
          "Citadel.PersistedSessionEnvelope",
          fn value ->
            Value.string!(value, "Citadel.PersistedSessionEnvelope.signal_cursor")
          end,
          nil
        ),
      recent_signal_hashes:
        Value.optional(
          attrs,
          :recent_signal_hashes,
          "Citadel.PersistedSessionEnvelope",
          fn value ->
            Value.unique_strings!(value, "Citadel.PersistedSessionEnvelope.recent_signal_hashes")
          end,
          []
        ),
      lifecycle_status:
        Value.required(attrs, :lifecycle_status, "Citadel.PersistedSessionEnvelope", fn value ->
          Value.enum!(
            value,
            SessionState.allowed_lifecycle_statuses(),
            "Citadel.PersistedSessionEnvelope.lifecycle_status"
          )
        end),
      last_active_at:
        Value.optional(
          attrs,
          :last_active_at,
          "Citadel.PersistedSessionEnvelope",
          fn value ->
            Value.datetime!(value, "Citadel.PersistedSessionEnvelope.last_active_at")
          end,
          nil
        ),
      active_plan:
        Value.optional(
          attrs,
          :active_plan,
          "Citadel.PersistedSessionEnvelope",
          fn value ->
            Value.module!(value, Plan, "Citadel.PersistedSessionEnvelope.active_plan")
          end,
          nil
        ),
      active_authority_decision:
        Value.optional(
          attrs,
          :active_authority_decision,
          "Citadel.PersistedSessionEnvelope",
          fn value ->
            Value.module!(
              value,
              AuthorityDecision,
              "Citadel.PersistedSessionEnvelope.active_authority_decision"
            )
          end,
          nil
        ),
      last_rejection:
        Value.optional(
          attrs,
          :last_rejection,
          "Citadel.PersistedSessionEnvelope",
          fn value ->
            Value.module!(
              value,
              DecisionRejection,
              "Citadel.PersistedSessionEnvelope.last_rejection"
            )
          end,
          nil
        ),
      boundary_ref:
        Value.optional(
          attrs,
          :boundary_ref,
          "Citadel.PersistedSessionEnvelope",
          fn value ->
            Value.string!(value, "Citadel.PersistedSessionEnvelope.boundary_ref")
          end,
          nil
        ),
      outbox_entry_ids:
        Value.required(attrs, :outbox_entry_ids, "Citadel.PersistedSessionEnvelope", fn value ->
          Value.unique_strings!(value, "Citadel.PersistedSessionEnvelope.outbox_entry_ids")
        end),
      external_refs:
        Value.optional(
          attrs,
          :external_refs,
          "Citadel.PersistedSessionEnvelope",
          fn value ->
            Value.json_object!(value, "Citadel.PersistedSessionEnvelope.external_refs")
          end,
          %{}
        ),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.PersistedSessionEnvelope",
          fn value ->
            Value.json_object!(value, "Citadel.PersistedSessionEnvelope.extensions")
          end,
          %{}
        )
    }
  end

  def dump(%__MODULE__{} = envelope) do
    %{
      schema_version: envelope.schema_version,
      session_id: envelope.session_id,
      continuity_revision: envelope.continuity_revision,
      owner_incarnation: envelope.owner_incarnation,
      project_binding: maybe_dump(envelope.project_binding),
      scope_ref: maybe_dump(envelope.scope_ref),
      signal_cursor: envelope.signal_cursor,
      recent_signal_hashes: envelope.recent_signal_hashes,
      lifecycle_status: envelope.lifecycle_status,
      last_active_at: envelope.last_active_at,
      active_plan: maybe_dump(envelope.active_plan),
      active_authority_decision: maybe_dump(envelope.active_authority_decision),
      last_rejection: maybe_dump(envelope.last_rejection),
      boundary_ref: envelope.boundary_ref,
      outbox_entry_ids: envelope.outbox_entry_ids,
      external_refs: envelope.external_refs,
      extensions: envelope.extensions
    }
  end

  defp maybe_dump(nil), do: nil
  defp maybe_dump(%module{} = struct), do: module.dump(struct)
end
