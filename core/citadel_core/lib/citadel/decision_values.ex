defmodule Citadel.Objective do
  @moduledoc """
  Normalized structured objective derived from `IntentEnvelope`.
  """

  alias Citadel.ContractCore.Value
  alias Citadel.IntentEnvelope.Constraints
  alias Citadel.IntentEnvelope.SuccessCriterion
  alias Citadel.ResolutionProvenance

  @allowed_priorities [:low, :normal, :high, :urgent]
  @schema [
    objective_id: :string,
    kind: :string,
    intent_spec: {:map, :json},
    constraints: {:struct, Constraints},
    success_criteria: {:list, {:struct, SuccessCriterion}},
    priority: {:enum, @allowed_priorities},
    provenance: {:struct, ResolutionProvenance},
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          objective_id: String.t(),
          kind: String.t(),
          intent_spec: map(),
          constraints: Constraints.t(),
          success_criteria: [SuccessCriterion.t()],
          priority: :low | :normal | :high | :urgent,
          provenance: ResolutionProvenance.t() | nil,
          extensions: map()
        }

  @enforce_keys [:objective_id, :kind, :intent_spec, :constraints, :success_criteria, :priority]
  defstruct objective_id: nil,
            kind: nil,
            intent_spec: %{},
            constraints: nil,
            success_criteria: [],
            priority: :normal,
            provenance: nil,
            extensions: %{}

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.Objective", @fields)

    %__MODULE__{
      objective_id:
        Value.required(attrs, :objective_id, "Citadel.Objective", fn value ->
          Value.string!(value, "Citadel.Objective.objective_id")
        end),
      kind:
        Value.required(attrs, :kind, "Citadel.Objective", fn value ->
          Value.string!(value, "Citadel.Objective.kind")
        end),
      intent_spec:
        Value.required(attrs, :intent_spec, "Citadel.Objective", fn value ->
          Value.json_object!(value, "Citadel.Objective.intent_spec")
        end),
      constraints:
        Value.required(attrs, :constraints, "Citadel.Objective", fn value ->
          Value.module!(value, Constraints, "Citadel.Objective.constraints")
        end),
      success_criteria:
        Value.required(attrs, :success_criteria, "Citadel.Objective", fn value ->
          Value.list!(value, "Citadel.Objective.success_criteria", fn item ->
            Value.module!(item, SuccessCriterion, "Citadel.Objective.success_criteria")
          end)
        end),
      priority:
        Value.required(attrs, :priority, "Citadel.Objective", fn value ->
          Value.enum!(value, @allowed_priorities, "Citadel.Objective.priority")
        end),
      provenance:
        Value.optional(
          attrs,
          :provenance,
          "Citadel.Objective",
          fn value ->
            Value.module!(value, ResolutionProvenance, "Citadel.Objective.provenance")
          end,
          nil
        ),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.Objective",
          fn value ->
            Value.json_object!(value, "Citadel.Objective.extensions")
          end,
          %{}
        )
    }
  end

  def dump(%__MODULE__{} = objective) do
    %{
      objective_id: objective.objective_id,
      kind: objective.kind,
      intent_spec: objective.intent_spec,
      constraints: Constraints.dump(objective.constraints),
      success_criteria: Enum.map(objective.success_criteria, &SuccessCriterion.dump/1),
      priority: objective.priority,
      provenance: maybe_dump(objective.provenance),
      extensions: objective.extensions
    }
  end

  defp maybe_dump(nil), do: nil
  defp maybe_dump(%module{} = struct), do: module.dump(struct)
end

defmodule Citadel.DecisionRejection do
  @moduledoc """
  Explicit pure-core rejection result for valid but unplannable or disallowed work.
  """

  alias Citadel.ContractCore.Value

  @allowed_stages [
    :ingress_normalization,
    :scope_resolution,
    :service_admission,
    :planning,
    :authority_compilation,
    :projection
  ]
  @allowed_retryability [
    :terminal,
    :after_input_change,
    :after_runtime_change,
    :after_governance_change
  ]
  @allowed_publication [:host_only, :review_projection, :derived_state_attachment]
  @schema [
    rejection_id: :string,
    stage: {:enum, @allowed_stages},
    reason_code: :string,
    summary: :string,
    retryability: {:enum, @allowed_retryability},
    publication_requirement: {:enum, @allowed_publication},
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type retryability ::
          :terminal | :after_input_change | :after_runtime_change | :after_governance_change
  @type publication_requirement :: :host_only | :review_projection | :derived_state_attachment

  @type t :: %__MODULE__{
          rejection_id: String.t(),
          stage: atom(),
          reason_code: String.t(),
          summary: String.t(),
          retryability: retryability(),
          publication_requirement: publication_requirement(),
          extensions: map()
        }

  @enforce_keys @fields
  defstruct @fields

  def schema, do: @schema
  def allowed_retryability, do: @allowed_retryability
  def allowed_publication_requirements, do: @allowed_publication
  def classification_posture, do: :pure_pipeline

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.DecisionRejection", @fields)

    %__MODULE__{
      rejection_id:
        Value.required(attrs, :rejection_id, "Citadel.DecisionRejection", fn value ->
          Value.string!(value, "Citadel.DecisionRejection.rejection_id")
        end),
      stage:
        Value.required(attrs, :stage, "Citadel.DecisionRejection", fn value ->
          Value.enum!(value, @allowed_stages, "Citadel.DecisionRejection.stage")
        end),
      reason_code:
        Value.required(attrs, :reason_code, "Citadel.DecisionRejection", fn value ->
          Value.string!(value, "Citadel.DecisionRejection.reason_code")
        end),
      summary:
        Value.required(attrs, :summary, "Citadel.DecisionRejection", fn value ->
          Value.string!(value, "Citadel.DecisionRejection.summary")
        end),
      retryability:
        Value.required(attrs, :retryability, "Citadel.DecisionRejection", fn value ->
          Value.enum!(value, @allowed_retryability, "Citadel.DecisionRejection.retryability")
        end),
      publication_requirement:
        Value.required(attrs, :publication_requirement, "Citadel.DecisionRejection", fn value ->
          Value.enum!(
            value,
            @allowed_publication,
            "Citadel.DecisionRejection.publication_requirement"
          )
        end),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.DecisionRejection",
          fn value ->
            Value.json_object!(value, "Citadel.DecisionRejection.extensions")
          end,
          %{}
        )
    }
  end

  def dump(%__MODULE__{} = rejection) do
    %{
      rejection_id: rejection.rejection_id,
      stage: rejection.stage,
      reason_code: rejection.reason_code,
      summary: rejection.summary,
      retryability: rejection.retryability,
      publication_requirement: rejection.publication_requirement,
      extensions: rejection.extensions
    }
  end
end

defmodule Citadel.DecisionRejectionClassifier do
  @moduledoc """
  Pure rejection classification step driven by explicit policy-pack rules.
  """

  alias Citadel.ContractCore.Value
  alias Citadel.DecisionRejection
  alias Citadel.PolicyPacks.PolicyPack
  alias Citadel.PolicyPacks.Selection

  @allowed_causes [
    :input,
    :runtime_state,
    :governance,
    :policy_denial,
    :planning
  ]
  @input_fields [:rejection_id, :stage, :reason_code, :summary, :causes, :extensions]

  def allowed_causes, do: @allowed_causes

  def classify!(attrs, %Selection{} = selection), do: classify!(attrs, selection.rejection_policy)
  def classify!(attrs, %PolicyPack{} = pack), do: classify!(attrs, pack.rejection_policy)

  def classify!(attrs, rejection_policy) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.DecisionRejectionClassifier", @input_fields)

    causes =
      normalize_causes!(
        Value.optional(attrs, :causes, "Citadel.DecisionRejectionClassifier", & &1, [])
      )

    reason_code =
      Value.required(attrs, :reason_code, "Citadel.DecisionRejectionClassifier", fn value ->
        Value.string!(value, "Citadel.DecisionRejectionClassifier.reason_code")
      end)

    DecisionRejection.new!(%{
      rejection_id:
        Value.required(attrs, :rejection_id, "Citadel.DecisionRejectionClassifier", fn value ->
          Value.string!(value, "Citadel.DecisionRejectionClassifier.rejection_id")
        end),
      stage:
        Value.required(attrs, :stage, "Citadel.DecisionRejectionClassifier", fn value ->
          Value.enum!(
            value,
            [
              :ingress_normalization,
              :scope_resolution,
              :service_admission,
              :planning,
              :authority_compilation,
              :projection
            ],
            "Citadel.DecisionRejectionClassifier.stage"
          )
        end),
      reason_code: reason_code,
      summary:
        Value.required(attrs, :summary, "Citadel.DecisionRejectionClassifier", fn value ->
          Value.string!(value, "Citadel.DecisionRejectionClassifier.summary")
        end),
      retryability: classify_retryability(causes, reason_code, rejection_policy),
      publication_requirement:
        classify_publication_requirement(causes, reason_code, rejection_policy),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.DecisionRejectionClassifier",
          fn value ->
            Value.json_object!(value, "Citadel.DecisionRejectionClassifier.extensions")
          end,
          %{}
        )
    })
  end

  defp normalize_causes!(causes) when is_list(causes) do
    causes
    |> Enum.map(&Value.enum!(&1, @allowed_causes, "Citadel.DecisionRejectionClassifier.causes"))
    |> Enum.uniq()
  end

  defp normalize_causes!(value) do
    raise ArgumentError,
          "Citadel.DecisionRejectionClassifier.causes must be a list, got: #{inspect(value)}"
  end

  defp classify_retryability(causes, reason_code, rejection_policy) do
    cond do
      :governance in causes or reason_code in rejection_policy.governance_change_reason_codes ->
        :after_governance_change

      :input in causes ->
        :after_input_change

      :runtime_state in causes or reason_code in rejection_policy.runtime_change_reason_codes ->
        :after_runtime_change

      true ->
        :terminal
    end
  end

  defp classify_publication_requirement(causes, reason_code, rejection_policy) do
    governance_or_denial_audit? =
      :governance in causes or
        :policy_denial in causes or
        reason_code in rejection_policy.denial_audit_reason_codes

    cond do
      governance_or_denial_audit? ->
        :review_projection

      reason_code in rejection_policy.derived_state_reason_codes ->
        :derived_state_attachment

      true ->
        :host_only
    end
  end
end

defmodule Citadel.AuthorityDecision do
  @moduledoc """
  Internal Brain authority value projected into `AuthorityDecision.v1`.
  """

  alias Citadel.ContractCore.Value

  @schema [
    contract_version: :string,
    decision_id: :string,
    tenant_id: :string,
    request_id: :string,
    policy_version: :string,
    boundary_class: :string,
    trust_profile: :string,
    approval_profile: :string,
    egress_profile: :string,
    workspace_profile: :string,
    resource_profile: :string,
    decision_hash: :string,
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          contract_version: String.t(),
          decision_id: String.t(),
          tenant_id: String.t(),
          request_id: String.t(),
          policy_version: String.t(),
          boundary_class: String.t(),
          trust_profile: String.t(),
          approval_profile: String.t(),
          egress_profile: String.t(),
          workspace_profile: String.t(),
          resource_profile: String.t(),
          decision_hash: String.t(),
          extensions: map()
        }

  @enforce_keys @fields
  defstruct @fields

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.AuthorityDecision", @fields)

    %__MODULE__{
      contract_version:
        Value.required(attrs, :contract_version, "Citadel.AuthorityDecision", fn value ->
          Value.string!(value, "Citadel.AuthorityDecision.contract_version")
        end),
      decision_id:
        Value.required(attrs, :decision_id, "Citadel.AuthorityDecision", fn value ->
          Value.string!(value, "Citadel.AuthorityDecision.decision_id")
        end),
      tenant_id:
        Value.required(attrs, :tenant_id, "Citadel.AuthorityDecision", fn value ->
          Value.string!(value, "Citadel.AuthorityDecision.tenant_id")
        end),
      request_id:
        Value.required(attrs, :request_id, "Citadel.AuthorityDecision", fn value ->
          Value.string!(value, "Citadel.AuthorityDecision.request_id")
        end),
      policy_version:
        Value.required(attrs, :policy_version, "Citadel.AuthorityDecision", fn value ->
          Value.string!(value, "Citadel.AuthorityDecision.policy_version")
        end),
      boundary_class:
        Value.required(attrs, :boundary_class, "Citadel.AuthorityDecision", fn value ->
          Value.string!(value, "Citadel.AuthorityDecision.boundary_class")
        end),
      trust_profile:
        Value.required(attrs, :trust_profile, "Citadel.AuthorityDecision", fn value ->
          Value.string!(value, "Citadel.AuthorityDecision.trust_profile")
        end),
      approval_profile:
        Value.required(attrs, :approval_profile, "Citadel.AuthorityDecision", fn value ->
          Value.string!(value, "Citadel.AuthorityDecision.approval_profile")
        end),
      egress_profile:
        Value.required(attrs, :egress_profile, "Citadel.AuthorityDecision", fn value ->
          Value.string!(value, "Citadel.AuthorityDecision.egress_profile")
        end),
      workspace_profile:
        Value.required(attrs, :workspace_profile, "Citadel.AuthorityDecision", fn value ->
          Value.string!(value, "Citadel.AuthorityDecision.workspace_profile")
        end),
      resource_profile:
        Value.required(attrs, :resource_profile, "Citadel.AuthorityDecision", fn value ->
          Value.string!(value, "Citadel.AuthorityDecision.resource_profile")
        end),
      decision_hash:
        Value.required(attrs, :decision_hash, "Citadel.AuthorityDecision", fn value ->
          Value.string!(value, "Citadel.AuthorityDecision.decision_hash")
        end),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.AuthorityDecision",
          fn value ->
            Value.json_object!(value, "Citadel.AuthorityDecision.extensions")
          end,
          %{}
        )
    }
  end

  def dump(%__MODULE__{} = authority) do
    %{
      contract_version: authority.contract_version,
      decision_id: authority.decision_id,
      tenant_id: authority.tenant_id,
      request_id: authority.request_id,
      policy_version: authority.policy_version,
      boundary_class: authority.boundary_class,
      trust_profile: authority.trust_profile,
      approval_profile: authority.approval_profile,
      egress_profile: authority.egress_profile,
      workspace_profile: authority.workspace_profile,
      resource_profile: authority.resource_profile,
      decision_hash: authority.decision_hash,
      extensions: authority.extensions
    }
  end
end

defmodule Citadel.Step do
  @moduledoc """
  One explicit planned step.
  """

  alias Citadel.BoundaryIntent
  alias Citadel.ContractCore.Value
  alias Citadel.IntentEnvelope.TargetHint

  @schema [
    step_id: :string,
    kind: :string,
    capability_id: :string,
    allowed_operations: {:list, :string},
    target_hints: {:list, {:struct, TargetHint}},
    boundary_intent: {:struct, BoundaryIntent},
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          step_id: String.t(),
          kind: String.t(),
          capability_id: String.t(),
          allowed_operations: [String.t()],
          target_hints: [TargetHint.t()],
          boundary_intent: BoundaryIntent.t() | nil,
          extensions: map()
        }

  @enforce_keys [:step_id, :kind, :capability_id, :allowed_operations]
  defstruct step_id: nil,
            kind: nil,
            capability_id: nil,
            allowed_operations: [],
            target_hints: [],
            boundary_intent: nil,
            extensions: %{}

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.Step", @fields)

    %__MODULE__{
      step_id:
        Value.required(attrs, :step_id, "Citadel.Step", fn value ->
          Value.string!(value, "Citadel.Step.step_id")
        end),
      kind:
        Value.required(attrs, :kind, "Citadel.Step", fn value ->
          Value.string!(value, "Citadel.Step.kind")
        end),
      capability_id:
        Value.required(attrs, :capability_id, "Citadel.Step", fn value ->
          Value.string!(value, "Citadel.Step.capability_id")
        end),
      allowed_operations:
        Value.required(attrs, :allowed_operations, "Citadel.Step", fn value ->
          Value.unique_strings!(value, "Citadel.Step.allowed_operations")
        end),
      target_hints:
        Value.optional(
          attrs,
          :target_hints,
          "Citadel.Step",
          fn value ->
            Value.list!(value, "Citadel.Step.target_hints", fn item ->
              Value.module!(item, TargetHint, "Citadel.Step.target_hints")
            end)
          end,
          []
        ),
      boundary_intent:
        Value.optional(
          attrs,
          :boundary_intent,
          "Citadel.Step",
          fn value ->
            Value.module!(value, BoundaryIntent, "Citadel.Step.boundary_intent")
          end,
          nil
        ),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.Step",
          fn value ->
            Value.json_object!(value, "Citadel.Step.extensions")
          end,
          %{}
        )
    }
  end

  def dump(%__MODULE__{} = step) do
    %{
      step_id: step.step_id,
      kind: step.kind,
      capability_id: step.capability_id,
      allowed_operations: step.allowed_operations,
      target_hints: Enum.map(step.target_hints, &TargetHint.dump/1),
      boundary_intent: maybe_dump(step.boundary_intent),
      extensions: step.extensions
    }
  end

  defp maybe_dump(nil), do: nil
  defp maybe_dump(%module{} = struct), do: module.dump(struct)
end

defmodule Citadel.Plan do
  @moduledoc """
  Ordered plan for one objective.
  """

  alias Citadel.ContractCore.Value
  alias Citadel.Step

  @schema [
    plan_id: :string,
    objective_id: :string,
    steps: {:list, {:struct, Step}},
    selection_mode: :string,
    budget_policy: {:map, :json},
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          plan_id: String.t(),
          objective_id: String.t(),
          steps: [Step.t()],
          selection_mode: String.t(),
          budget_policy: map(),
          extensions: map()
        }

  @enforce_keys [:plan_id, :objective_id, :steps, :selection_mode, :budget_policy]
  defstruct plan_id: nil,
            objective_id: nil,
            steps: [],
            selection_mode: nil,
            budget_policy: %{},
            extensions: %{}

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.Plan", @fields)

    %__MODULE__{
      plan_id:
        Value.required(attrs, :plan_id, "Citadel.Plan", fn value ->
          Value.string!(value, "Citadel.Plan.plan_id")
        end),
      objective_id:
        Value.required(attrs, :objective_id, "Citadel.Plan", fn value ->
          Value.string!(value, "Citadel.Plan.objective_id")
        end),
      steps:
        Value.required(attrs, :steps, "Citadel.Plan", fn value ->
          Value.list!(
            value,
            "Citadel.Plan.steps",
            fn item ->
              Value.module!(item, Step, "Citadel.Plan.steps")
            end,
            allow_empty?: false
          )
        end),
      selection_mode:
        Value.required(attrs, :selection_mode, "Citadel.Plan", fn value ->
          Value.string!(value, "Citadel.Plan.selection_mode")
        end),
      budget_policy:
        Value.required(attrs, :budget_policy, "Citadel.Plan", fn value ->
          Value.json_object!(value, "Citadel.Plan.budget_policy")
        end),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.Plan",
          fn value ->
            Value.json_object!(value, "Citadel.Plan.extensions")
          end,
          %{}
        )
    }
  end

  def dump(%__MODULE__{} = plan) do
    %{
      plan_id: plan.plan_id,
      objective_id: plan.objective_id,
      steps: Enum.map(plan.steps, &Step.dump/1),
      selection_mode: plan.selection_mode,
      budget_policy: plan.budget_policy,
      extensions: plan.extensions
    }
  end
end
