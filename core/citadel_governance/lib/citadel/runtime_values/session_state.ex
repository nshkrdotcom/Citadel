defmodule Citadel.SessionState do
  @moduledoc """
  Live mutable session state reconstructed from persisted continuity plus local visibility.
  """

  alias Citadel.AuthorityDecision
  alias Citadel.BoundaryLeaseView
  alias Citadel.ContractCore.Value
  alias Citadel.DecisionRejection
  alias Citadel.Plan
  alias Citadel.ProjectBinding
  alias Citadel.ScopeRef
  alias Citadel.ServiceDescriptor
  alias Citadel.SessionOutbox

  @allowed_lifecycle_statuses [
    :active,
    :idle,
    :completed,
    :abandoned,
    :reclaiming,
    :evicted,
    :resume_pending,
    :resume_failed,
    :blocked,
    :quarantined
  ]
  @schema [
    session_id: :string,
    continuity_revision: :non_neg_integer,
    owner_incarnation: :positive_integer,
    project_binding: {:struct, ProjectBinding},
    scope_ref: {:struct, ScopeRef},
    signal_cursor: :string,
    recent_signal_hashes: {:list, :string},
    last_active_at: :datetime,
    lifecycle_status: {:enum, @allowed_lifecycle_statuses},
    active_plan: {:struct, Plan},
    active_authority_decision: {:struct, AuthorityDecision},
    last_rejection: {:struct, DecisionRejection},
    visible_services: {:list, {:struct, ServiceDescriptor}},
    boundary_lease_view: {:struct, BoundaryLeaseView},
    outbox: {:struct, SessionOutbox},
    external_refs: {:map, :json},
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type lifecycle_status ::
          :active
          | :idle
          | :completed
          | :abandoned
          | :reclaiming
          | :evicted
          | :resume_pending
          | :resume_failed
          | :blocked
          | :quarantined

  @type t :: %__MODULE__{
          session_id: String.t(),
          continuity_revision: non_neg_integer(),
          owner_incarnation: pos_integer(),
          project_binding: ProjectBinding.t() | nil,
          scope_ref: ScopeRef.t() | nil,
          signal_cursor: String.t() | nil,
          recent_signal_hashes: [String.t()],
          last_active_at: DateTime.t() | nil,
          lifecycle_status: lifecycle_status(),
          active_plan: Plan.t() | nil,
          active_authority_decision: AuthorityDecision.t() | nil,
          last_rejection: DecisionRejection.t() | nil,
          visible_services: [ServiceDescriptor.t()],
          boundary_lease_view: BoundaryLeaseView.t() | nil,
          outbox: SessionOutbox.t(),
          external_refs: map(),
          extensions: map()
        }

  @enforce_keys [
    :session_id,
    :continuity_revision,
    :owner_incarnation,
    :lifecycle_status,
    :outbox
  ]
  defstruct session_id: nil,
            continuity_revision: 0,
            owner_incarnation: 1,
            project_binding: nil,
            scope_ref: nil,
            signal_cursor: nil,
            recent_signal_hashes: [],
            last_active_at: nil,
            lifecycle_status: :active,
            active_plan: nil,
            active_authority_decision: nil,
            last_rejection: nil,
            visible_services: [],
            boundary_lease_view: nil,
            outbox: nil,
            external_refs: %{},
            extensions: %{}

  def schema, do: @schema
  def allowed_lifecycle_statuses, do: @allowed_lifecycle_statuses

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.SessionState", @fields)

    %__MODULE__{
      session_id:
        Value.required(attrs, :session_id, "Citadel.SessionState", fn value ->
          Value.string!(value, "Citadel.SessionState.session_id")
        end),
      continuity_revision:
        Value.required(attrs, :continuity_revision, "Citadel.SessionState", fn value ->
          Value.non_neg_integer!(value, "Citadel.SessionState.continuity_revision")
        end),
      owner_incarnation:
        Value.required(attrs, :owner_incarnation, "Citadel.SessionState", fn value ->
          Value.positive_integer!(value, "Citadel.SessionState.owner_incarnation")
        end),
      project_binding:
        Value.optional(
          attrs,
          :project_binding,
          "Citadel.SessionState",
          fn value ->
            Value.module!(value, ProjectBinding, "Citadel.SessionState.project_binding")
          end,
          nil
        ),
      scope_ref:
        Value.optional(
          attrs,
          :scope_ref,
          "Citadel.SessionState",
          fn value ->
            Value.module!(value, ScopeRef, "Citadel.SessionState.scope_ref")
          end,
          nil
        ),
      signal_cursor:
        Value.optional(
          attrs,
          :signal_cursor,
          "Citadel.SessionState",
          fn value ->
            Value.string!(value, "Citadel.SessionState.signal_cursor")
          end,
          nil
        ),
      recent_signal_hashes:
        Value.optional(
          attrs,
          :recent_signal_hashes,
          "Citadel.SessionState",
          fn value ->
            Value.unique_strings!(value, "Citadel.SessionState.recent_signal_hashes")
          end,
          []
        ),
      last_active_at:
        Value.optional(
          attrs,
          :last_active_at,
          "Citadel.SessionState",
          fn value ->
            Value.datetime!(value, "Citadel.SessionState.last_active_at")
          end,
          nil
        ),
      lifecycle_status:
        Value.required(attrs, :lifecycle_status, "Citadel.SessionState", fn value ->
          Value.enum!(value, @allowed_lifecycle_statuses, "Citadel.SessionState.lifecycle_status")
        end),
      active_plan:
        Value.optional(
          attrs,
          :active_plan,
          "Citadel.SessionState",
          fn value ->
            Value.module!(value, Plan, "Citadel.SessionState.active_plan")
          end,
          nil
        ),
      active_authority_decision:
        Value.optional(
          attrs,
          :active_authority_decision,
          "Citadel.SessionState",
          fn value ->
            Value.module!(
              value,
              AuthorityDecision,
              "Citadel.SessionState.active_authority_decision"
            )
          end,
          nil
        ),
      last_rejection:
        Value.optional(
          attrs,
          :last_rejection,
          "Citadel.SessionState",
          fn value ->
            Value.module!(value, DecisionRejection, "Citadel.SessionState.last_rejection")
          end,
          nil
        ),
      visible_services:
        Value.optional(
          attrs,
          :visible_services,
          "Citadel.SessionState",
          fn value ->
            Value.list!(value, "Citadel.SessionState.visible_services", fn item ->
              Value.module!(item, ServiceDescriptor, "Citadel.SessionState.visible_services")
            end)
          end,
          []
        ),
      boundary_lease_view:
        Value.optional(
          attrs,
          :boundary_lease_view,
          "Citadel.SessionState",
          fn value ->
            Value.module!(value, BoundaryLeaseView, "Citadel.SessionState.boundary_lease_view")
          end,
          nil
        ),
      outbox:
        Value.required(attrs, :outbox, "Citadel.SessionState", fn value ->
          Value.module!(value, SessionOutbox, "Citadel.SessionState.outbox")
        end),
      external_refs:
        Value.optional(
          attrs,
          :external_refs,
          "Citadel.SessionState",
          fn value ->
            Value.json_object!(value, "Citadel.SessionState.external_refs")
          end,
          %{}
        ),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.SessionState",
          fn value ->
            Value.json_object!(value, "Citadel.SessionState.extensions")
          end,
          %{}
        )
    }
  end

  def dump(%__MODULE__{} = state) do
    %{
      session_id: state.session_id,
      continuity_revision: state.continuity_revision,
      owner_incarnation: state.owner_incarnation,
      project_binding: maybe_dump(state.project_binding),
      scope_ref: maybe_dump(state.scope_ref),
      signal_cursor: state.signal_cursor,
      recent_signal_hashes: state.recent_signal_hashes,
      last_active_at: state.last_active_at,
      lifecycle_status: state.lifecycle_status,
      active_plan: maybe_dump(state.active_plan),
      active_authority_decision: maybe_dump(state.active_authority_decision),
      last_rejection: maybe_dump(state.last_rejection),
      visible_services: Enum.map(state.visible_services, &ServiceDescriptor.dump/1),
      boundary_lease_view: maybe_dump(state.boundary_lease_view),
      outbox: SessionOutbox.dump(state.outbox),
      external_refs: state.external_refs,
      extensions: state.extensions
    }
  end

  defp maybe_dump(nil), do: nil
  defp maybe_dump(%module{} = struct), do: module.dump(struct)
end
