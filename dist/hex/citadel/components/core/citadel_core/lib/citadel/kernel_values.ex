defmodule Citadel.DecisionSnapshot do
  @moduledoc """
  Immutable aggregate decision snapshot captured before a pure decision pass.
  """

  alias Citadel.ContractCore.Value

  @schema [
    snapshot_seq: :non_neg_integer,
    captured_at: :datetime,
    policy_version: :string,
    policy_epoch: :non_neg_integer,
    topology_epoch: :non_neg_integer,
    scope_catalog_epoch: :non_neg_integer,
    service_admission_epoch: :non_neg_integer,
    project_binding_epoch: :non_neg_integer,
    boundary_epoch: :non_neg_integer,
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          snapshot_seq: non_neg_integer(),
          captured_at: DateTime.t(),
          policy_version: String.t(),
          policy_epoch: non_neg_integer(),
          topology_epoch: non_neg_integer(),
          scope_catalog_epoch: non_neg_integer(),
          service_admission_epoch: non_neg_integer(),
          project_binding_epoch: non_neg_integer(),
          boundary_epoch: non_neg_integer(),
          extensions: map()
        }

  @enforce_keys @fields
  defstruct @fields

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.DecisionSnapshot", @fields)

    %__MODULE__{
      snapshot_seq:
        Value.required(attrs, :snapshot_seq, "Citadel.DecisionSnapshot", fn value ->
          Value.non_neg_integer!(value, "Citadel.DecisionSnapshot.snapshot_seq")
        end),
      captured_at:
        Value.required(attrs, :captured_at, "Citadel.DecisionSnapshot", fn value ->
          Value.datetime!(value, "Citadel.DecisionSnapshot.captured_at")
        end),
      policy_version:
        Value.required(attrs, :policy_version, "Citadel.DecisionSnapshot", fn value ->
          Value.string!(value, "Citadel.DecisionSnapshot.policy_version")
        end),
      policy_epoch:
        Value.required(attrs, :policy_epoch, "Citadel.DecisionSnapshot", fn value ->
          Value.non_neg_integer!(value, "Citadel.DecisionSnapshot.policy_epoch")
        end),
      topology_epoch:
        Value.required(attrs, :topology_epoch, "Citadel.DecisionSnapshot", fn value ->
          Value.non_neg_integer!(value, "Citadel.DecisionSnapshot.topology_epoch")
        end),
      scope_catalog_epoch:
        Value.required(attrs, :scope_catalog_epoch, "Citadel.DecisionSnapshot", fn value ->
          Value.non_neg_integer!(value, "Citadel.DecisionSnapshot.scope_catalog_epoch")
        end),
      service_admission_epoch:
        Value.required(attrs, :service_admission_epoch, "Citadel.DecisionSnapshot", fn value ->
          Value.non_neg_integer!(value, "Citadel.DecisionSnapshot.service_admission_epoch")
        end),
      project_binding_epoch:
        Value.required(attrs, :project_binding_epoch, "Citadel.DecisionSnapshot", fn value ->
          Value.non_neg_integer!(value, "Citadel.DecisionSnapshot.project_binding_epoch")
        end),
      boundary_epoch:
        Value.required(attrs, :boundary_epoch, "Citadel.DecisionSnapshot", fn value ->
          Value.non_neg_integer!(value, "Citadel.DecisionSnapshot.boundary_epoch")
        end),
      extensions:
        Value.optional(attrs, :extensions, "Citadel.DecisionSnapshot", fn value ->
          Value.json_object!(value, "Citadel.DecisionSnapshot.extensions")
        end, %{})
    }
  end

  def dump(%__MODULE__{} = snapshot) do
    %{
      snapshot_seq: snapshot.snapshot_seq,
      captured_at: snapshot.captured_at,
      policy_version: snapshot.policy_version,
      policy_epoch: snapshot.policy_epoch,
      topology_epoch: snapshot.topology_epoch,
      scope_catalog_epoch: snapshot.scope_catalog_epoch,
      service_admission_epoch: snapshot.service_admission_epoch,
      project_binding_epoch: snapshot.project_binding_epoch,
      boundary_epoch: snapshot.boundary_epoch,
      extensions: snapshot.extensions
    }
  end
end

defmodule Citadel.KernelEpochUpdate do
  @moduledoc """
  Explicit constituent epoch update emitted into `KernelSnapshot`.
  """

  alias Citadel.ContractCore.Value

  @allowed_constituents [
    :policy_epoch,
    :topology_epoch,
    :scope_catalog_epoch,
    :service_admission_epoch,
    :project_binding_epoch,
    :boundary_epoch
  ]
  @schema [
    source_owner: :string,
    constituent: {:enum, @allowed_constituents},
    epoch: :non_neg_integer,
    updated_at: :datetime,
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type constituent ::
          :policy_epoch
          | :topology_epoch
          | :scope_catalog_epoch
          | :service_admission_epoch
          | :project_binding_epoch
          | :boundary_epoch

  @type t :: %__MODULE__{
          source_owner: String.t(),
          constituent: constituent(),
          epoch: non_neg_integer(),
          updated_at: DateTime.t(),
          extensions: map()
        }

  @enforce_keys @fields
  defstruct @fields

  def schema, do: @schema
  def allowed_constituents, do: @allowed_constituents
  def extension_rule, do: :packet_revision_required_for_new_constituent

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.KernelEpochUpdate", @fields)

    %__MODULE__{
      source_owner:
        Value.required(attrs, :source_owner, "Citadel.KernelEpochUpdate", fn value ->
          Value.string!(value, "Citadel.KernelEpochUpdate.source_owner")
        end),
      constituent:
        Value.required(attrs, :constituent, "Citadel.KernelEpochUpdate", fn value ->
          Value.enum!(value, @allowed_constituents, "Citadel.KernelEpochUpdate.constituent")
        end),
      epoch:
        Value.required(attrs, :epoch, "Citadel.KernelEpochUpdate", fn value ->
          Value.non_neg_integer!(value, "Citadel.KernelEpochUpdate.epoch")
        end),
      updated_at:
        Value.required(attrs, :updated_at, "Citadel.KernelEpochUpdate", fn value ->
          Value.datetime!(value, "Citadel.KernelEpochUpdate.updated_at")
        end),
      extensions:
        Value.optional(attrs, :extensions, "Citadel.KernelEpochUpdate", fn value ->
          Value.json_object!(value, "Citadel.KernelEpochUpdate.extensions")
        end, %{})
    }
  end

  def dump(%__MODULE__{} = update) do
    %{
      source_owner: update.source_owner,
      constituent: update.constituent,
      epoch: update.epoch,
      updated_at: update.updated_at,
      extensions: update.extensions
    }
  end
end

defmodule Citadel.ScopeRef do
  @moduledoc """
  Explicit host-local scope reference for kernel interpretation.
  """

  alias Citadel.ContractCore.Value

  @schema [
    scope_id: :string,
    scope_kind: :string,
    workspace_root: :string,
    environment: :string,
    catalog_epoch: :non_neg_integer,
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          scope_id: String.t(),
          scope_kind: String.t(),
          workspace_root: String.t(),
          environment: String.t(),
          catalog_epoch: non_neg_integer(),
          extensions: map()
        }

  @enforce_keys @fields
  defstruct @fields

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.ScopeRef", @fields)

    %__MODULE__{
      scope_id:
        Value.required(attrs, :scope_id, "Citadel.ScopeRef", fn value ->
          Value.string!(value, "Citadel.ScopeRef.scope_id")
        end),
      scope_kind:
        Value.required(attrs, :scope_kind, "Citadel.ScopeRef", fn value ->
          Value.string!(value, "Citadel.ScopeRef.scope_kind")
        end),
      workspace_root:
        Value.required(attrs, :workspace_root, "Citadel.ScopeRef", fn value ->
          Value.string!(value, "Citadel.ScopeRef.workspace_root")
        end),
      environment:
        Value.required(attrs, :environment, "Citadel.ScopeRef", fn value ->
          Value.string!(value, "Citadel.ScopeRef.environment")
        end),
      catalog_epoch:
        Value.required(attrs, :catalog_epoch, "Citadel.ScopeRef", fn value ->
          Value.non_neg_integer!(value, "Citadel.ScopeRef.catalog_epoch")
        end),
      extensions:
        Value.optional(attrs, :extensions, "Citadel.ScopeRef", fn value ->
          Value.json_object!(value, "Citadel.ScopeRef.extensions")
        end, %{})
    }
  end

  def dump(%__MODULE__{} = scope_ref) do
    %{
      scope_id: scope_ref.scope_id,
      scope_kind: scope_ref.scope_kind,
      workspace_root: scope_ref.workspace_root,
      environment: scope_ref.environment,
      catalog_epoch: scope_ref.catalog_epoch,
      extensions: scope_ref.extensions
    }
  end
end

defmodule Citadel.TargetResolution do
  @moduledoc """
  Explicit result of host-local target resolution.
  """

  alias Citadel.ContractCore.Value

  @schema [
    target_id: :string,
    target_kind: :string,
    target_capabilities: {:list, :string},
    boundary_capabilities: {:list, :string},
    selection_reason: :string,
    catalog_epoch: :non_neg_integer,
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          target_id: String.t(),
          target_kind: String.t(),
          target_capabilities: [String.t()],
          boundary_capabilities: [String.t()],
          selection_reason: String.t(),
          catalog_epoch: non_neg_integer(),
          extensions: map()
        }

  @enforce_keys @fields
  defstruct @fields

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.TargetResolution", @fields)

    %__MODULE__{
      target_id:
        Value.required(attrs, :target_id, "Citadel.TargetResolution", fn value ->
          Value.string!(value, "Citadel.TargetResolution.target_id")
        end),
      target_kind:
        Value.required(attrs, :target_kind, "Citadel.TargetResolution", fn value ->
          Value.string!(value, "Citadel.TargetResolution.target_kind")
        end),
      target_capabilities:
        Value.required(attrs, :target_capabilities, "Citadel.TargetResolution", fn value ->
          Value.unique_strings!(value, "Citadel.TargetResolution.target_capabilities")
        end),
      boundary_capabilities:
        Value.required(attrs, :boundary_capabilities, "Citadel.TargetResolution", fn value ->
          Value.unique_strings!(value, "Citadel.TargetResolution.boundary_capabilities")
        end),
      selection_reason:
        Value.required(attrs, :selection_reason, "Citadel.TargetResolution", fn value ->
          Value.string!(value, "Citadel.TargetResolution.selection_reason")
        end),
      catalog_epoch:
        Value.required(attrs, :catalog_epoch, "Citadel.TargetResolution", fn value ->
          Value.non_neg_integer!(value, "Citadel.TargetResolution.catalog_epoch")
        end),
      extensions:
        Value.optional(attrs, :extensions, "Citadel.TargetResolution", fn value ->
          Value.json_object!(value, "Citadel.TargetResolution.extensions")
        end, %{})
    }
  end

  def dump(%__MODULE__{} = resolution) do
    %{
      target_id: resolution.target_id,
      target_kind: resolution.target_kind,
      target_capabilities: resolution.target_capabilities,
      boundary_capabilities: resolution.boundary_capabilities,
      selection_reason: resolution.selection_reason,
      catalog_epoch: resolution.catalog_epoch,
      extensions: resolution.extensions
    }
  end
end

defmodule Citadel.ProjectBinding do
  @moduledoc """
  Durable host-local binding between a session and project/workspace.
  """

  alias Citadel.ContractCore.Value

  @schema [
    binding_id: :string,
    session_id: :string,
    project_id: :string,
    workspace_root: :string,
    binding_epoch: :non_neg_integer,
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          binding_id: String.t(),
          session_id: String.t(),
          project_id: String.t(),
          workspace_root: String.t(),
          binding_epoch: non_neg_integer(),
          extensions: map()
        }

  @enforce_keys @fields
  defstruct @fields

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.ProjectBinding", @fields)

    %__MODULE__{
      binding_id:
        Value.required(attrs, :binding_id, "Citadel.ProjectBinding", fn value ->
          Value.string!(value, "Citadel.ProjectBinding.binding_id")
        end),
      session_id:
        Value.required(attrs, :session_id, "Citadel.ProjectBinding", fn value ->
          Value.string!(value, "Citadel.ProjectBinding.session_id")
        end),
      project_id:
        Value.required(attrs, :project_id, "Citadel.ProjectBinding", fn value ->
          Value.string!(value, "Citadel.ProjectBinding.project_id")
        end),
      workspace_root:
        Value.required(attrs, :workspace_root, "Citadel.ProjectBinding", fn value ->
          Value.string!(value, "Citadel.ProjectBinding.workspace_root")
        end),
      binding_epoch:
        Value.required(attrs, :binding_epoch, "Citadel.ProjectBinding", fn value ->
          Value.non_neg_integer!(value, "Citadel.ProjectBinding.binding_epoch")
        end),
      extensions:
        Value.optional(attrs, :extensions, "Citadel.ProjectBinding", fn value ->
          Value.json_object!(value, "Citadel.ProjectBinding.extensions")
        end, %{})
    }
  end

  def dump(%__MODULE__{} = binding) do
    %{
      binding_id: binding.binding_id,
      session_id: binding.session_id,
      project_id: binding.project_id,
      workspace_root: binding.workspace_root,
      binding_epoch: binding.binding_epoch,
      extensions: binding.extensions
    }
  end
end

defmodule Citadel.ServiceDescriptor do
  @moduledoc """
  Explicit visible service descriptor.
  """

  alias Citadel.ContractCore.Value

  @schema [
    service_id: :string,
    service_kind: :string,
    capabilities: {:list, :string},
    visibility: :string,
    admission_epoch: :non_neg_integer,
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          service_id: String.t(),
          service_kind: String.t(),
          capabilities: [String.t()],
          visibility: String.t(),
          admission_epoch: non_neg_integer(),
          extensions: map()
        }

  @enforce_keys @fields
  defstruct @fields

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.ServiceDescriptor", @fields)

    %__MODULE__{
      service_id:
        Value.required(attrs, :service_id, "Citadel.ServiceDescriptor", fn value ->
          Value.string!(value, "Citadel.ServiceDescriptor.service_id")
        end),
      service_kind:
        Value.required(attrs, :service_kind, "Citadel.ServiceDescriptor", fn value ->
          Value.string!(value, "Citadel.ServiceDescriptor.service_kind")
        end),
      capabilities:
        Value.required(attrs, :capabilities, "Citadel.ServiceDescriptor", fn value ->
          Value.unique_strings!(value, "Citadel.ServiceDescriptor.capabilities")
        end),
      visibility:
        Value.required(attrs, :visibility, "Citadel.ServiceDescriptor", fn value ->
          Value.string!(value, "Citadel.ServiceDescriptor.visibility")
        end),
      admission_epoch:
        Value.required(attrs, :admission_epoch, "Citadel.ServiceDescriptor", fn value ->
          Value.non_neg_integer!(value, "Citadel.ServiceDescriptor.admission_epoch")
        end),
      extensions:
        Value.optional(attrs, :extensions, "Citadel.ServiceDescriptor", fn value ->
          Value.json_object!(value, "Citadel.ServiceDescriptor.extensions")
        end, %{})
    }
  end

  def dump(%__MODULE__{} = descriptor) do
    %{
      service_id: descriptor.service_id,
      service_kind: descriptor.service_kind,
      capabilities: descriptor.capabilities,
      visibility: descriptor.visibility,
      admission_epoch: descriptor.admission_epoch,
      extensions: descriptor.extensions
    }
  end
end

defmodule Citadel.ExtensionAdmission do
  @moduledoc """
  Explicit admission result for one visible local service.
  """

  alias Citadel.ContractCore.Value

  @allowed_statuses [:admitted, :denied, :hidden, :stale]
  @schema [
    service_id: :string,
    status: {:enum, @allowed_statuses},
    reason_code: :string,
    effective_policy_version: :string,
    admission_epoch: :non_neg_integer,
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type status :: :admitted | :denied | :hidden | :stale

  @type t :: %__MODULE__{
          service_id: String.t(),
          status: status(),
          reason_code: String.t(),
          effective_policy_version: String.t(),
          admission_epoch: non_neg_integer(),
          extensions: map()
        }

  @enforce_keys @fields
  defstruct @fields

  def schema, do: @schema
  def allowed_statuses, do: @allowed_statuses

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.ExtensionAdmission", @fields)

    %__MODULE__{
      service_id:
        Value.required(attrs, :service_id, "Citadel.ExtensionAdmission", fn value ->
          Value.string!(value, "Citadel.ExtensionAdmission.service_id")
        end),
      status:
        Value.required(attrs, :status, "Citadel.ExtensionAdmission", fn value ->
          Value.enum!(value, @allowed_statuses, "Citadel.ExtensionAdmission.status")
        end),
      reason_code:
        Value.required(attrs, :reason_code, "Citadel.ExtensionAdmission", fn value ->
          Value.string!(value, "Citadel.ExtensionAdmission.reason_code")
        end),
      effective_policy_version:
        Value.required(attrs, :effective_policy_version, "Citadel.ExtensionAdmission", fn value ->
          Value.string!(value, "Citadel.ExtensionAdmission.effective_policy_version")
        end),
      admission_epoch:
        Value.required(attrs, :admission_epoch, "Citadel.ExtensionAdmission", fn value ->
          Value.non_neg_integer!(value, "Citadel.ExtensionAdmission.admission_epoch")
        end),
      extensions:
        Value.optional(attrs, :extensions, "Citadel.ExtensionAdmission", fn value ->
          Value.json_object!(value, "Citadel.ExtensionAdmission.extensions")
        end, %{})
    }
  end

  def dump(%__MODULE__{} = admission) do
    %{
      service_id: admission.service_id,
      status: admission.status,
      reason_code: admission.reason_code,
      effective_policy_version: admission.effective_policy_version,
      admission_epoch: admission.admission_epoch,
      extensions: admission.extensions
    }
  end
end

defmodule Citadel.BoundaryLeaseView do
  @moduledoc """
  Host-local view of one boundary's liveness and reuse posture.
  """

  alias Citadel.ContractCore.Value

  @allowed_statuses [:fresh, :stale, :expired, :missing]
  @schema [
    boundary_ref: :string,
    last_heartbeat_at: :datetime,
    expires_at: :datetime,
    staleness_status: {:enum, @allowed_statuses},
    lease_epoch: :non_neg_integer,
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type staleness_status :: :fresh | :stale | :expired | :missing

  @type t :: %__MODULE__{
          boundary_ref: String.t(),
          last_heartbeat_at: DateTime.t() | nil,
          expires_at: DateTime.t() | nil,
          staleness_status: staleness_status(),
          lease_epoch: non_neg_integer(),
          extensions: map()
        }

  @enforce_keys [:boundary_ref, :staleness_status, :lease_epoch, :extensions]
  defstruct boundary_ref: nil,
            last_heartbeat_at: nil,
            expires_at: nil,
            staleness_status: :missing,
            lease_epoch: 0,
            extensions: %{}

  def schema, do: @schema
  def allowed_statuses, do: @allowed_statuses

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.BoundaryLeaseView", @fields)

    boundary_ref =
      Value.required(attrs, :boundary_ref, "Citadel.BoundaryLeaseView", fn value ->
        Value.string!(value, "Citadel.BoundaryLeaseView.boundary_ref")
      end)

    staleness_status =
      Value.required(attrs, :staleness_status, "Citadel.BoundaryLeaseView", fn value ->
        Value.enum!(value, @allowed_statuses, "Citadel.BoundaryLeaseView.staleness_status")
      end)

    lease_view = %__MODULE__{
      boundary_ref: boundary_ref,
      last_heartbeat_at:
        Value.optional(attrs, :last_heartbeat_at, "Citadel.BoundaryLeaseView", fn value ->
          Value.datetime!(value, "Citadel.BoundaryLeaseView.last_heartbeat_at")
        end, nil),
      expires_at:
        Value.optional(attrs, :expires_at, "Citadel.BoundaryLeaseView", fn value ->
          Value.datetime!(value, "Citadel.BoundaryLeaseView.expires_at")
        end, nil),
      staleness_status: staleness_status,
      lease_epoch:
        Value.required(attrs, :lease_epoch, "Citadel.BoundaryLeaseView", fn value ->
          Value.non_neg_integer!(value, "Citadel.BoundaryLeaseView.lease_epoch")
        end),
      extensions:
        Value.optional(attrs, :extensions, "Citadel.BoundaryLeaseView", fn value ->
          Value.json_object!(value, "Citadel.BoundaryLeaseView.extensions")
        end, %{})
    }

    validate_missing_boundary_fields!(lease_view)
  end

  def dump(%__MODULE__{} = lease_view) do
    %{
      boundary_ref: lease_view.boundary_ref,
      last_heartbeat_at: lease_view.last_heartbeat_at,
      expires_at: lease_view.expires_at,
      staleness_status: lease_view.staleness_status,
      lease_epoch: lease_view.lease_epoch,
      extensions: lease_view.extensions
    }
  end

  defp validate_missing_boundary_fields!(%__MODULE__{staleness_status: :missing} = lease_view) do
    if lease_view.last_heartbeat_at || lease_view.expires_at do
      raise ArgumentError,
            "Citadel.BoundaryLeaseView missing boundaries must not carry heartbeat timestamps"
    end

    lease_view
  end

  defp validate_missing_boundary_fields!(lease_view), do: lease_view
end

defmodule Citadel.KernelContext do
  @moduledoc """
  Canonical pre-planning context assembled from structured ingress and policy selection.
  """

  alias Citadel.ContractCore.Value
  alias Citadel.DecisionSnapshot
  alias Citadel.ProjectBinding
  alias Citadel.ScopeRef
  alias Citadel.ServiceDescriptor
  alias Citadel.TargetResolution

  @schema [
    request_id: :string,
    tenant_id: :string,
    trace_id: :string,
    actor_id: :string,
    session_id: :string,
    scope_ref: {:struct, ScopeRef},
    policy_version: :string,
    policy_epoch: :non_neg_integer,
    topology_epoch: :non_neg_integer,
    trust_profile: :string,
    approval_profile: :string,
    egress_profile: :string,
    workspace_profile: :string,
    resource_profile: :string,
    boundary_class: :string,
    decision_snapshot: {:struct, DecisionSnapshot},
    project_binding: {:struct, ProjectBinding},
    selected_target: {:struct, TargetResolution},
    selected_service: {:struct, ServiceDescriptor},
    existing_boundary_ref: :string,
    signal_cursor: :string,
    external_refs: {:map, :json},
    extensions: {:map, :json}
  ]
  @required_fields [
    :request_id,
    :tenant_id,
    :trace_id,
    :actor_id,
    :session_id,
    :scope_ref,
    :policy_version,
    :policy_epoch,
    :topology_epoch,
    :trust_profile,
    :approval_profile,
    :egress_profile,
    :workspace_profile,
    :resource_profile,
    :boundary_class
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          request_id: String.t(),
          tenant_id: String.t(),
          trace_id: String.t(),
          actor_id: String.t(),
          session_id: String.t(),
          scope_ref: ScopeRef.t(),
          policy_version: String.t(),
          policy_epoch: non_neg_integer(),
          topology_epoch: non_neg_integer(),
          trust_profile: String.t(),
          approval_profile: String.t(),
          egress_profile: String.t(),
          workspace_profile: String.t(),
          resource_profile: String.t(),
          boundary_class: String.t(),
          decision_snapshot: DecisionSnapshot.t() | nil,
          project_binding: ProjectBinding.t() | nil,
          selected_target: TargetResolution.t() | nil,
          selected_service: ServiceDescriptor.t() | nil,
          existing_boundary_ref: String.t() | nil,
          signal_cursor: String.t() | nil,
          external_refs: map(),
          extensions: map()
        }

  @enforce_keys @required_fields
  defstruct @required_fields ++
              [
                decision_snapshot: nil,
                project_binding: nil,
                selected_target: nil,
                selected_service: nil,
                existing_boundary_ref: nil,
                signal_cursor: nil,
                external_refs: %{},
                extensions: %{}
              ]

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.KernelContext", @fields)

    %__MODULE__{
      request_id:
        Value.required(attrs, :request_id, "Citadel.KernelContext", fn value ->
          Value.string!(value, "Citadel.KernelContext.request_id")
        end),
      tenant_id:
        Value.required(attrs, :tenant_id, "Citadel.KernelContext", fn value ->
          Value.string!(value, "Citadel.KernelContext.tenant_id")
        end),
      trace_id:
        Value.required(attrs, :trace_id, "Citadel.KernelContext", fn value ->
          Value.string!(value, "Citadel.KernelContext.trace_id")
        end),
      actor_id:
        Value.required(attrs, :actor_id, "Citadel.KernelContext", fn value ->
          Value.string!(value, "Citadel.KernelContext.actor_id")
        end),
      session_id:
        Value.required(attrs, :session_id, "Citadel.KernelContext", fn value ->
          Value.string!(value, "Citadel.KernelContext.session_id")
        end),
      scope_ref:
        Value.required(attrs, :scope_ref, "Citadel.KernelContext", fn value ->
          Value.module!(value, ScopeRef, "Citadel.KernelContext.scope_ref")
        end),
      policy_version:
        Value.required(attrs, :policy_version, "Citadel.KernelContext", fn value ->
          Value.string!(value, "Citadel.KernelContext.policy_version")
        end),
      policy_epoch:
        Value.required(attrs, :policy_epoch, "Citadel.KernelContext", fn value ->
          Value.non_neg_integer!(value, "Citadel.KernelContext.policy_epoch")
        end),
      topology_epoch:
        Value.required(attrs, :topology_epoch, "Citadel.KernelContext", fn value ->
          Value.non_neg_integer!(value, "Citadel.KernelContext.topology_epoch")
        end),
      trust_profile:
        Value.required(attrs, :trust_profile, "Citadel.KernelContext", fn value ->
          Value.string!(value, "Citadel.KernelContext.trust_profile")
        end),
      approval_profile:
        Value.required(attrs, :approval_profile, "Citadel.KernelContext", fn value ->
          Value.string!(value, "Citadel.KernelContext.approval_profile")
        end),
      egress_profile:
        Value.required(attrs, :egress_profile, "Citadel.KernelContext", fn value ->
          Value.string!(value, "Citadel.KernelContext.egress_profile")
        end),
      workspace_profile:
        Value.required(attrs, :workspace_profile, "Citadel.KernelContext", fn value ->
          Value.string!(value, "Citadel.KernelContext.workspace_profile")
        end),
      resource_profile:
        Value.required(attrs, :resource_profile, "Citadel.KernelContext", fn value ->
          Value.string!(value, "Citadel.KernelContext.resource_profile")
        end),
      boundary_class:
        Value.required(attrs, :boundary_class, "Citadel.KernelContext", fn value ->
          Value.string!(value, "Citadel.KernelContext.boundary_class")
        end),
      decision_snapshot:
        Value.optional(attrs, :decision_snapshot, "Citadel.KernelContext", fn value ->
          Value.module!(value, DecisionSnapshot, "Citadel.KernelContext.decision_snapshot")
        end, nil),
      project_binding:
        Value.optional(attrs, :project_binding, "Citadel.KernelContext", fn value ->
          Value.module!(value, ProjectBinding, "Citadel.KernelContext.project_binding")
        end, nil),
      selected_target:
        Value.optional(attrs, :selected_target, "Citadel.KernelContext", fn value ->
          Value.module!(value, TargetResolution, "Citadel.KernelContext.selected_target")
        end, nil),
      selected_service:
        Value.optional(attrs, :selected_service, "Citadel.KernelContext", fn value ->
          Value.module!(value, ServiceDescriptor, "Citadel.KernelContext.selected_service")
        end, nil),
      existing_boundary_ref:
        Value.optional(attrs, :existing_boundary_ref, "Citadel.KernelContext", fn value ->
          Value.string!(value, "Citadel.KernelContext.existing_boundary_ref")
        end, nil),
      signal_cursor:
        Value.optional(attrs, :signal_cursor, "Citadel.KernelContext", fn value ->
          Value.string!(value, "Citadel.KernelContext.signal_cursor")
        end, nil),
      external_refs:
        Value.optional(attrs, :external_refs, "Citadel.KernelContext", fn value ->
          Value.json_object!(value, "Citadel.KernelContext.external_refs")
        end, %{}),
      extensions:
        Value.optional(attrs, :extensions, "Citadel.KernelContext", fn value ->
          Value.json_object!(value, "Citadel.KernelContext.extensions")
        end, %{})
    }
  end

  def dump(%__MODULE__{} = context) do
    %{
      request_id: context.request_id,
      tenant_id: context.tenant_id,
      trace_id: context.trace_id,
      actor_id: context.actor_id,
      session_id: context.session_id,
      scope_ref: Citadel.ScopeRef.dump(context.scope_ref),
      policy_version: context.policy_version,
      policy_epoch: context.policy_epoch,
      topology_epoch: context.topology_epoch,
      trust_profile: context.trust_profile,
      approval_profile: context.approval_profile,
      egress_profile: context.egress_profile,
      workspace_profile: context.workspace_profile,
      resource_profile: context.resource_profile,
      boundary_class: context.boundary_class,
      decision_snapshot: maybe_dump(context.decision_snapshot),
      project_binding: maybe_dump(context.project_binding),
      selected_target: maybe_dump(context.selected_target),
      selected_service: maybe_dump(context.selected_service),
      existing_boundary_ref: context.existing_boundary_ref,
      signal_cursor: context.signal_cursor,
      external_refs: context.external_refs,
      extensions: context.extensions
    }
  end

  defp maybe_dump(nil), do: nil
  defp maybe_dump(%module{} = struct), do: module.dump(struct)
end
