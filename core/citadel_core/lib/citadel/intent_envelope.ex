defmodule Citadel.IntentMappingConstraints do
  @moduledoc """
  Frozen Wave 3 value-level mappings that later feed `BoundaryIntent` and `TopologyIntent`.
  """

  alias Citadel.ContractCore.Value
  alias Citadel.IntentEnvelope
  alias Citadel.IntentEnvelope.Constraints
  alias Citadel.IntentEnvelope.TargetHint

  @allowed_boundary_requirements [:reuse_existing, :fresh_or_reuse, :fresh_only, :no_boundary]
  @allowed_session_modes [:attached, :detached, :stateless]
  @allowed_coordination_modes [:single_target, :parallel_fanout, :local_only]
  @allowed_attach_modes ["reuse_existing", "fresh_or_reuse", "fresh_only", "not_applicable"]

  def allowed_boundary_requirements, do: @allowed_boundary_requirements
  def allowed_session_modes, do: @allowed_session_modes
  def allowed_coordination_modes, do: @allowed_coordination_modes
  def allowed_attach_modes, do: @allowed_attach_modes

  def carrier_shape_change_criteria do
    [
      :field_inventory,
      :requiredness,
      :field_type,
      :field_ownership,
      :public_field_meaning
    ]
  end

  def value_mapping_change_examples do
    [
      :selector_vocabularies,
      :defaults,
      :allowed_values,
      :population_rules
    ]
  end

  def boundary_attach_mode_for(:reuse_existing), do: "reuse_existing"
  def boundary_attach_mode_for(:fresh_or_reuse), do: "fresh_or_reuse"
  def boundary_attach_mode_for(:fresh_only), do: "fresh_only"
  def boundary_attach_mode_for(:no_boundary), do: "not_applicable"

  def boundary_attach_mode_for(value),
    do:
      raise(
        ArgumentError,
        "Citadel.IntentMappingConstraints boundary requirement is invalid: #{inspect(value)}"
      )

  def topology_session_mode_for(constraints, target_hints) do
    constraints =
      Value.module!(
        constraints,
        Constraints,
        "Citadel.IntentMappingConstraints.constraints"
      )

    target_hints = normalize_target_hints!(target_hints)

    if constraints.boundary_requirement == :no_boundary do
      :stateless
    else
      target_hints
      |> Enum.map(& &1.session_mode_preference)
      |> Enum.reject(&is_nil/1)
      |> List.first()
      |> Kernel.||(:attached)
    end
  end

  def coordination_mode_for(target_hints) do
    target_hints = normalize_target_hints!(target_hints)

    target_hints
    |> Enum.map(& &1.coordination_mode_preference)
    |> Enum.reject(&is_nil/1)
    |> List.first()
    |> Kernel.||(:single_target)
  end

  def boundary_mapping(envelope) do
    envelope = normalize_envelope!(envelope)

    %{
      requested_attach_mode: boundary_attach_mode_for(envelope.constraints.boundary_requirement),
      preferred_boundary_class:
        envelope.target_hints
        |> Enum.map(& &1.preferred_boundary_class)
        |> Enum.reject(&is_nil/1)
        |> List.first(),
      allowed_boundary_classes: envelope.constraints.allowed_boundary_classes
    }
  end

  def topology_mapping(envelope) do
    envelope = normalize_envelope!(envelope)

    %{
      session_mode: topology_session_mode_for(envelope.constraints, envelope.target_hints),
      coordination_mode: coordination_mode_for(envelope.target_hints),
      routing_hints: %{
        preferred_target_ids:
          envelope.target_hints
          |> Enum.map(& &1.preferred_target_id)
          |> Enum.reject(&is_nil/1),
        preferred_service_ids:
          envelope.target_hints
          |> Enum.map(& &1.preferred_service_id)
          |> Enum.reject(&is_nil/1),
        routing_tags:
          envelope.target_hints
          |> Enum.flat_map(& &1.routing_tags)
          |> Enum.uniq()
      }
    }
  end

  def planning_status(envelope) do
    envelope = normalize_envelope!(envelope)
    session_mode = topology_session_mode_for(envelope.constraints, envelope.target_hints)

    cond do
      envelope.constraints.boundary_requirement == :reuse_existing and
          session_mode in [:detached, :stateless] ->
        {:unplannable, "boundary_reuse_requires_attached_session"}

      envelope.desired_outcome.outcome_kind == :inspect_scope and
          envelope.constraints.boundary_requirement == :fresh_only ->
        {:unplannable, "inspect_scope_cannot_require_fresh_only_boundary"}

      true ->
        :plannable
    end
  end

  defp normalize_envelope!(%{__struct__: IntentEnvelope} = envelope) do
    revalidate_struct!(
      envelope,
      "Citadel.IntentMappingConstraints envelope",
      &IntentEnvelope.dump/1,
      &IntentEnvelope.new!/1
    )
  end

  defp normalize_envelope!(value) do
    Value.module!(value, IntentEnvelope, "Citadel.IntentMappingConstraints envelope")
  end

  defp normalize_target_hints!(value) do
    Value.list!(value, "Citadel.IntentMappingConstraints.target_hints", fn target_hint ->
      Value.module!(
        target_hint,
        TargetHint,
        "Citadel.IntentMappingConstraints.target_hints"
      )
    end)
  end

  defp revalidate_struct!(value, label, dump_fun, new_fun) do
    dump_fun.(value)
    |> new_fun.()
  rescue
    error in [
      ArgumentError,
      ArithmeticError,
      BadMapError,
      FunctionClauseError,
      KeyError,
      Protocol.UndefinedError
    ] ->
      reraise ArgumentError.exception("#{label} is invalid: #{Exception.message(error)}"),
              __STACKTRACE__
  end
end

defmodule Citadel.ResolutionProvenance do
  @moduledoc """
  Explicit provenance for how a structured `IntentEnvelope` was formed.
  """

  alias Citadel.ContractCore.Value

  @schema [
    source_kind: :string,
    resolver_kind: :string,
    resolver_version: :string,
    prompt_version: :string,
    policy_version: :string,
    confidence: :float,
    ambiguity_flags: {:list, :string},
    raw_input_refs: {:list, :string},
    raw_input_hashes: {:list, :string},
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          source_kind: String.t(),
          resolver_kind: String.t() | nil,
          resolver_version: String.t() | nil,
          prompt_version: String.t() | nil,
          policy_version: String.t() | nil,
          confidence: float() | nil,
          ambiguity_flags: [String.t()],
          raw_input_refs: [String.t()],
          raw_input_hashes: [String.t()],
          extensions: map()
        }

  @enforce_keys [:source_kind]
  defstruct source_kind: nil,
            resolver_kind: nil,
            resolver_version: nil,
            prompt_version: nil,
            policy_version: nil,
            confidence: nil,
            ambiguity_flags: [],
            raw_input_refs: [],
            raw_input_hashes: [],
            extensions: %{}

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.ResolutionProvenance", @fields)

    %__MODULE__{
      source_kind:
        Value.required(attrs, :source_kind, "Citadel.ResolutionProvenance", fn value ->
          Value.string!(value, "Citadel.ResolutionProvenance.source_kind")
        end),
      resolver_kind:
        Value.optional(
          attrs,
          :resolver_kind,
          "Citadel.ResolutionProvenance",
          fn value ->
            Value.string!(value, "Citadel.ResolutionProvenance.resolver_kind")
          end,
          nil
        ),
      resolver_version:
        Value.optional(
          attrs,
          :resolver_version,
          "Citadel.ResolutionProvenance",
          fn value ->
            Value.string!(value, "Citadel.ResolutionProvenance.resolver_version")
          end,
          nil
        ),
      prompt_version:
        Value.optional(
          attrs,
          :prompt_version,
          "Citadel.ResolutionProvenance",
          fn value ->
            Value.string!(value, "Citadel.ResolutionProvenance.prompt_version")
          end,
          nil
        ),
      policy_version:
        Value.optional(
          attrs,
          :policy_version,
          "Citadel.ResolutionProvenance",
          fn value ->
            Value.string!(value, "Citadel.ResolutionProvenance.policy_version")
          end,
          nil
        ),
      confidence:
        Value.optional(
          attrs,
          :confidence,
          "Citadel.ResolutionProvenance",
          fn value ->
            Value.confidence!(value, "Citadel.ResolutionProvenance.confidence")
          end,
          nil
        ),
      ambiguity_flags:
        Value.optional(
          attrs,
          :ambiguity_flags,
          "Citadel.ResolutionProvenance",
          fn value ->
            Value.unique_strings!(value, "Citadel.ResolutionProvenance.ambiguity_flags")
          end,
          []
        ),
      raw_input_refs:
        Value.optional(
          attrs,
          :raw_input_refs,
          "Citadel.ResolutionProvenance",
          fn value ->
            Value.unique_strings!(value, "Citadel.ResolutionProvenance.raw_input_refs")
          end,
          []
        ),
      raw_input_hashes:
        Value.optional(
          attrs,
          :raw_input_hashes,
          "Citadel.ResolutionProvenance",
          fn value ->
            Value.unique_strings!(value, "Citadel.ResolutionProvenance.raw_input_hashes")
          end,
          []
        ),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.ResolutionProvenance",
          fn value ->
            Value.json_object!(value, "Citadel.ResolutionProvenance.extensions")
          end,
          %{}
        )
    }
  end

  def dump(%__MODULE__{} = provenance) do
    %{
      source_kind: provenance.source_kind,
      resolver_kind: provenance.resolver_kind,
      resolver_version: provenance.resolver_version,
      prompt_version: provenance.prompt_version,
      policy_version: provenance.policy_version,
      confidence: provenance.confidence,
      ambiguity_flags: provenance.ambiguity_flags,
      raw_input_refs: provenance.raw_input_refs,
      raw_input_hashes: provenance.raw_input_hashes,
      extensions: provenance.extensions
    }
  end
end

defmodule Citadel.IntentEnvelope.ScopeSelector do
  @moduledoc """
  Structured scope selector carried by `Citadel.IntentEnvelope`.
  """

  alias Citadel.ContractCore.Value

  @allowed_preferences [:required, :preferred]
  @schema [
    scope_kind: :string,
    scope_id: :string,
    workspace_root: :string,
    environment: :string,
    preference: {:enum, @allowed_preferences},
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          scope_kind: String.t(),
          scope_id: String.t() | nil,
          workspace_root: String.t() | nil,
          environment: String.t() | nil,
          preference: :required | :preferred,
          extensions: map()
        }

  @enforce_keys [:scope_kind, :preference]
  defstruct scope_kind: nil,
            scope_id: nil,
            workspace_root: nil,
            environment: nil,
            preference: :required,
            extensions: %{}

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.IntentEnvelope.ScopeSelector", @fields)

    selector = %__MODULE__{
      scope_kind:
        Value.required(attrs, :scope_kind, "Citadel.IntentEnvelope.ScopeSelector", fn value ->
          Value.string!(value, "Citadel.IntentEnvelope.ScopeSelector.scope_kind")
        end),
      scope_id:
        Value.optional(
          attrs,
          :scope_id,
          "Citadel.IntentEnvelope.ScopeSelector",
          fn value ->
            Value.string!(value, "Citadel.IntentEnvelope.ScopeSelector.scope_id")
          end,
          nil
        ),
      workspace_root:
        Value.optional(
          attrs,
          :workspace_root,
          "Citadel.IntentEnvelope.ScopeSelector",
          fn value ->
            Value.string!(value, "Citadel.IntentEnvelope.ScopeSelector.workspace_root")
          end,
          nil
        ),
      environment:
        Value.optional(
          attrs,
          :environment,
          "Citadel.IntentEnvelope.ScopeSelector",
          fn value ->
            Value.string!(value, "Citadel.IntentEnvelope.ScopeSelector.environment")
          end,
          nil
        ),
      preference:
        Value.optional(
          attrs,
          :preference,
          "Citadel.IntentEnvelope.ScopeSelector",
          fn value ->
            Value.enum!(
              value,
              @allowed_preferences,
              "Citadel.IntentEnvelope.ScopeSelector.preference"
            )
          end,
          :required
        ),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.IntentEnvelope.ScopeSelector",
          fn value ->
            Value.json_object!(value, "Citadel.IntentEnvelope.ScopeSelector.extensions")
          end,
          %{}
        )
    }

    if is_nil(selector.scope_id) and is_nil(selector.workspace_root) do
      raise ArgumentError,
            "Citadel.IntentEnvelope.ScopeSelector requires scope_id or workspace_root"
    end

    selector
  end

  def dump(%__MODULE__{} = selector) do
    %{
      scope_kind: selector.scope_kind,
      scope_id: selector.scope_id,
      workspace_root: selector.workspace_root,
      environment: selector.environment,
      preference: selector.preference,
      extensions: selector.extensions
    }
  end
end

defmodule Citadel.IntentEnvelope.DesiredOutcome do
  @moduledoc """
  Structured desired-outcome record carried by `Citadel.IntentEnvelope`.
  """

  alias Citadel.ContractCore.Value

  @allowed_outcome_kinds [:invoke_capability, :inspect_scope, :maintain_session]
  @schema [
    outcome_kind: {:enum, @allowed_outcome_kinds},
    requested_capabilities: {:list, :string},
    result_kind: :string,
    subject_selectors: {:list, :string},
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          outcome_kind: :invoke_capability | :inspect_scope | :maintain_session,
          requested_capabilities: [String.t()],
          result_kind: String.t(),
          subject_selectors: [String.t()],
          extensions: map()
        }

  @enforce_keys [:outcome_kind, :requested_capabilities, :result_kind]
  defstruct outcome_kind: nil,
            requested_capabilities: [],
            result_kind: nil,
            subject_selectors: [],
            extensions: %{}

  def schema, do: @schema
  def allowed_outcome_kinds, do: @allowed_outcome_kinds

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.IntentEnvelope.DesiredOutcome", @fields)

    outcome = %__MODULE__{
      outcome_kind:
        Value.required(attrs, :outcome_kind, "Citadel.IntentEnvelope.DesiredOutcome", fn value ->
          Value.enum!(
            value,
            @allowed_outcome_kinds,
            "Citadel.IntentEnvelope.DesiredOutcome.outcome_kind"
          )
        end),
      requested_capabilities:
        Value.required(
          attrs,
          :requested_capabilities,
          "Citadel.IntentEnvelope.DesiredOutcome",
          fn value ->
            Value.unique_strings!(
              value,
              "Citadel.IntentEnvelope.DesiredOutcome.requested_capabilities"
            )
          end
        ),
      result_kind:
        Value.required(attrs, :result_kind, "Citadel.IntentEnvelope.DesiredOutcome", fn value ->
          Value.string!(value, "Citadel.IntentEnvelope.DesiredOutcome.result_kind")
        end),
      subject_selectors:
        Value.optional(
          attrs,
          :subject_selectors,
          "Citadel.IntentEnvelope.DesiredOutcome",
          fn value ->
            Value.unique_strings!(
              value,
              "Citadel.IntentEnvelope.DesiredOutcome.subject_selectors"
            )
          end,
          []
        ),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.IntentEnvelope.DesiredOutcome",
          fn value ->
            Value.json_object!(value, "Citadel.IntentEnvelope.DesiredOutcome.extensions")
          end,
          %{}
        )
    }

    if outcome.outcome_kind == :invoke_capability and outcome.requested_capabilities == [] do
      raise ArgumentError,
            "Citadel.IntentEnvelope.DesiredOutcome.requested_capabilities must not be empty for invoke_capability"
    end

    outcome
  end

  def dump(%__MODULE__{} = outcome) do
    %{
      outcome_kind: outcome.outcome_kind,
      requested_capabilities: outcome.requested_capabilities,
      result_kind: outcome.result_kind,
      subject_selectors: outcome.subject_selectors,
      extensions: outcome.extensions
    }
  end
end

defmodule Citadel.IntentEnvelope.Constraints do
  @moduledoc """
  Structured planning and execution constraints carried by `Citadel.IntentEnvelope`.
  """

  alias Citadel.ContractCore.Value
  alias Citadel.IntentMappingConstraints

  @schema [
    boundary_requirement: {:enum, IntentMappingConstraints.allowed_boundary_requirements()},
    allowed_boundary_classes: {:list, :string},
    allowed_service_ids: {:list, :string},
    forbidden_service_ids: {:list, :string},
    max_steps: :positive_integer,
    review_required: :boolean,
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          boundary_requirement: :reuse_existing | :fresh_or_reuse | :fresh_only | :no_boundary,
          allowed_boundary_classes: [String.t()],
          allowed_service_ids: [String.t()],
          forbidden_service_ids: [String.t()],
          max_steps: pos_integer(),
          review_required: boolean(),
          extensions: map()
        }

  @enforce_keys [:boundary_requirement, :max_steps, :review_required]
  defstruct boundary_requirement: :fresh_or_reuse,
            allowed_boundary_classes: [],
            allowed_service_ids: [],
            forbidden_service_ids: [],
            max_steps: 1,
            review_required: false,
            extensions: %{}

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.IntentEnvelope.Constraints", @fields)

    %__MODULE__{
      boundary_requirement:
        Value.required(
          attrs,
          :boundary_requirement,
          "Citadel.IntentEnvelope.Constraints",
          fn value ->
            Value.enum!(
              value,
              IntentMappingConstraints.allowed_boundary_requirements(),
              "Citadel.IntentEnvelope.Constraints.boundary_requirement"
            )
          end
        ),
      allowed_boundary_classes:
        Value.optional(
          attrs,
          :allowed_boundary_classes,
          "Citadel.IntentEnvelope.Constraints",
          fn value ->
            Value.unique_strings!(
              value,
              "Citadel.IntentEnvelope.Constraints.allowed_boundary_classes"
            )
          end,
          []
        ),
      allowed_service_ids:
        Value.optional(
          attrs,
          :allowed_service_ids,
          "Citadel.IntentEnvelope.Constraints",
          fn value ->
            Value.unique_strings!(value, "Citadel.IntentEnvelope.Constraints.allowed_service_ids")
          end,
          []
        ),
      forbidden_service_ids:
        Value.optional(
          attrs,
          :forbidden_service_ids,
          "Citadel.IntentEnvelope.Constraints",
          fn value ->
            Value.unique_strings!(
              value,
              "Citadel.IntentEnvelope.Constraints.forbidden_service_ids"
            )
          end,
          []
        ),
      max_steps:
        Value.required(attrs, :max_steps, "Citadel.IntentEnvelope.Constraints", fn value ->
          Value.positive_integer!(value, "Citadel.IntentEnvelope.Constraints.max_steps")
        end),
      review_required:
        Value.required(attrs, :review_required, "Citadel.IntentEnvelope.Constraints", fn value ->
          Value.boolean!(value, "Citadel.IntentEnvelope.Constraints.review_required")
        end),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.IntentEnvelope.Constraints",
          fn value ->
            Value.json_object!(value, "Citadel.IntentEnvelope.Constraints.extensions")
          end,
          %{}
        )
    }
  end

  def dump(%__MODULE__{} = constraints) do
    %{
      boundary_requirement: constraints.boundary_requirement,
      allowed_boundary_classes: constraints.allowed_boundary_classes,
      allowed_service_ids: constraints.allowed_service_ids,
      forbidden_service_ids: constraints.forbidden_service_ids,
      max_steps: constraints.max_steps,
      review_required: constraints.review_required,
      extensions: constraints.extensions
    }
  end
end

defmodule Citadel.IntentEnvelope.RiskHint do
  @moduledoc """
  Structured risk hint carried by `Citadel.IntentEnvelope`.
  """

  alias Citadel.ContractCore.Value

  @allowed_severities [:low, :medium, :high, :critical]
  @schema [
    risk_code: :string,
    severity: {:enum, @allowed_severities},
    requires_governance: :boolean,
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          risk_code: String.t(),
          severity: :low | :medium | :high | :critical,
          requires_governance: boolean(),
          extensions: map()
        }

  @enforce_keys [:risk_code, :severity, :requires_governance]
  defstruct risk_code: nil, severity: :low, requires_governance: false, extensions: %{}

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.IntentEnvelope.RiskHint", @fields)

    %__MODULE__{
      risk_code:
        Value.required(attrs, :risk_code, "Citadel.IntentEnvelope.RiskHint", fn value ->
          Value.string!(value, "Citadel.IntentEnvelope.RiskHint.risk_code")
        end),
      severity:
        Value.required(attrs, :severity, "Citadel.IntentEnvelope.RiskHint", fn value ->
          Value.enum!(value, @allowed_severities, "Citadel.IntentEnvelope.RiskHint.severity")
        end),
      requires_governance:
        Value.required(attrs, :requires_governance, "Citadel.IntentEnvelope.RiskHint", fn value ->
          Value.boolean!(value, "Citadel.IntentEnvelope.RiskHint.requires_governance")
        end),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.IntentEnvelope.RiskHint",
          fn value ->
            Value.json_object!(value, "Citadel.IntentEnvelope.RiskHint.extensions")
          end,
          %{}
        )
    }
  end

  def dump(%__MODULE__{} = hint) do
    %{
      risk_code: hint.risk_code,
      severity: hint.severity,
      requires_governance: hint.requires_governance,
      extensions: hint.extensions
    }
  end
end

defmodule Citadel.IntentEnvelope.SuccessCriterion do
  @moduledoc """
  Structured success criterion carried by `Citadel.IntentEnvelope`.
  """

  alias Citadel.ContractCore.Value

  @allowed_kinds [:completion, :artifact_presence, :signal_status]
  @schema [
    criterion_kind: {:enum, @allowed_kinds},
    metric: :string,
    target: :json,
    required: :boolean,
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          criterion_kind: :completion | :artifact_presence | :signal_status,
          metric: String.t(),
          target: term(),
          required: boolean(),
          extensions: map()
        }

  @enforce_keys [:criterion_kind, :metric, :target, :required]
  defstruct criterion_kind: nil, metric: nil, target: nil, required: true, extensions: %{}

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.IntentEnvelope.SuccessCriterion", @fields)

    %__MODULE__{
      criterion_kind:
        Value.required(
          attrs,
          :criterion_kind,
          "Citadel.IntentEnvelope.SuccessCriterion",
          fn value ->
            Value.enum!(
              value,
              @allowed_kinds,
              "Citadel.IntentEnvelope.SuccessCriterion.criterion_kind"
            )
          end
        ),
      metric:
        Value.required(attrs, :metric, "Citadel.IntentEnvelope.SuccessCriterion", fn value ->
          Value.string!(value, "Citadel.IntentEnvelope.SuccessCriterion.metric")
        end),
      target:
        Value.required(attrs, :target, "Citadel.IntentEnvelope.SuccessCriterion", fn value ->
          Value.json_value!(value, "Citadel.IntentEnvelope.SuccessCriterion.target")
        end),
      required:
        Value.required(attrs, :required, "Citadel.IntentEnvelope.SuccessCriterion", fn value ->
          Value.boolean!(value, "Citadel.IntentEnvelope.SuccessCriterion.required")
        end),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.IntentEnvelope.SuccessCriterion",
          fn value ->
            Value.json_object!(value, "Citadel.IntentEnvelope.SuccessCriterion.extensions")
          end,
          %{}
        )
    }
  end

  def dump(%__MODULE__{} = criterion) do
    %{
      criterion_kind: criterion.criterion_kind,
      metric: criterion.metric,
      target: criterion.target,
      required: criterion.required,
      extensions: criterion.extensions
    }
  end
end

defmodule Citadel.IntentEnvelope.TargetHint do
  @moduledoc """
  Structured target hint carried by `Citadel.IntentEnvelope`.
  """

  alias Citadel.ContractCore.Value
  alias Citadel.IntentMappingConstraints

  @schema [
    target_kind: :string,
    preferred_target_id: :string,
    preferred_service_id: :string,
    preferred_boundary_class: :string,
    session_mode_preference: {:enum, IntentMappingConstraints.allowed_session_modes()},
    coordination_mode_preference: {:enum, IntentMappingConstraints.allowed_coordination_modes()},
    routing_tags: {:list, :string},
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          target_kind: String.t(),
          preferred_target_id: String.t() | nil,
          preferred_service_id: String.t() | nil,
          preferred_boundary_class: String.t() | nil,
          session_mode_preference: :attached | :detached | :stateless | nil,
          coordination_mode_preference: :single_target | :parallel_fanout | :local_only | nil,
          routing_tags: [String.t()],
          extensions: map()
        }

  @enforce_keys [:target_kind]
  defstruct target_kind: nil,
            preferred_target_id: nil,
            preferred_service_id: nil,
            preferred_boundary_class: nil,
            session_mode_preference: nil,
            coordination_mode_preference: nil,
            routing_tags: [],
            extensions: %{}

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.IntentEnvelope.TargetHint", @fields)

    %__MODULE__{
      target_kind:
        Value.required(attrs, :target_kind, "Citadel.IntentEnvelope.TargetHint", fn value ->
          Value.string!(value, "Citadel.IntentEnvelope.TargetHint.target_kind")
        end),
      preferred_target_id:
        Value.optional(
          attrs,
          :preferred_target_id,
          "Citadel.IntentEnvelope.TargetHint",
          fn value ->
            Value.string!(value, "Citadel.IntentEnvelope.TargetHint.preferred_target_id")
          end,
          nil
        ),
      preferred_service_id:
        Value.optional(
          attrs,
          :preferred_service_id,
          "Citadel.IntentEnvelope.TargetHint",
          fn value ->
            Value.string!(value, "Citadel.IntentEnvelope.TargetHint.preferred_service_id")
          end,
          nil
        ),
      preferred_boundary_class:
        Value.optional(
          attrs,
          :preferred_boundary_class,
          "Citadel.IntentEnvelope.TargetHint",
          fn value ->
            Value.string!(value, "Citadel.IntentEnvelope.TargetHint.preferred_boundary_class")
          end,
          nil
        ),
      session_mode_preference:
        Value.optional(
          attrs,
          :session_mode_preference,
          "Citadel.IntentEnvelope.TargetHint",
          fn value ->
            Value.enum!(
              value,
              IntentMappingConstraints.allowed_session_modes(),
              "Citadel.IntentEnvelope.TargetHint.session_mode_preference"
            )
          end,
          nil
        ),
      coordination_mode_preference:
        Value.optional(
          attrs,
          :coordination_mode_preference,
          "Citadel.IntentEnvelope.TargetHint",
          fn value ->
            Value.enum!(
              value,
              IntentMappingConstraints.allowed_coordination_modes(),
              "Citadel.IntentEnvelope.TargetHint.coordination_mode_preference"
            )
          end,
          nil
        ),
      routing_tags:
        Value.optional(
          attrs,
          :routing_tags,
          "Citadel.IntentEnvelope.TargetHint",
          fn value ->
            Value.unique_strings!(value, "Citadel.IntentEnvelope.TargetHint.routing_tags")
          end,
          []
        ),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.IntentEnvelope.TargetHint",
          fn value ->
            Value.json_object!(value, "Citadel.IntentEnvelope.TargetHint.extensions")
          end,
          %{}
        )
    }
  end

  def dump(%__MODULE__{} = hint) do
    %{
      target_kind: hint.target_kind,
      preferred_target_id: hint.preferred_target_id,
      preferred_service_id: hint.preferred_service_id,
      preferred_boundary_class: hint.preferred_boundary_class,
      session_mode_preference: hint.session_mode_preference,
      coordination_mode_preference: hint.coordination_mode_preference,
      routing_tags: hint.routing_tags,
      extensions: hint.extensions
    }
  end
end

defmodule Citadel.PlanHints.CandidateStep do
  @moduledoc """
  Candidate-step hint used inside `Citadel.PlanHints`.
  """

  alias Citadel.ContractCore.Value

  @schema [
    step_kind: :string,
    capability_id: :string,
    allowed_operations: {:list, :string},
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          step_kind: String.t(),
          capability_id: String.t(),
          allowed_operations: [String.t()],
          extensions: map()
        }

  @enforce_keys [:step_kind, :capability_id, :allowed_operations]
  defstruct step_kind: nil, capability_id: nil, allowed_operations: [], extensions: %{}

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.PlanHints.CandidateStep", @fields)

    %__MODULE__{
      step_kind:
        Value.required(attrs, :step_kind, "Citadel.PlanHints.CandidateStep", fn value ->
          Value.string!(value, "Citadel.PlanHints.CandidateStep.step_kind")
        end),
      capability_id:
        Value.required(attrs, :capability_id, "Citadel.PlanHints.CandidateStep", fn value ->
          Value.string!(value, "Citadel.PlanHints.CandidateStep.capability_id")
        end),
      allowed_operations:
        Value.required(attrs, :allowed_operations, "Citadel.PlanHints.CandidateStep", fn value ->
          Value.unique_strings!(value, "Citadel.PlanHints.CandidateStep.allowed_operations")
        end),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.PlanHints.CandidateStep",
          fn value ->
            Value.json_object!(value, "Citadel.PlanHints.CandidateStep.extensions")
          end,
          %{}
        )
    }
  end

  def dump(%__MODULE__{} = step) do
    %{
      step_kind: step.step_kind,
      capability_id: step.capability_id,
      allowed_operations: step.allowed_operations,
      extensions: step.extensions
    }
  end
end

defmodule Citadel.PlanHints.BudgetHints do
  @moduledoc """
  Budget hint used inside `Citadel.PlanHints`.
  """

  alias Citadel.ContractCore.Value

  @schema [
    max_steps: :positive_integer,
    max_runtime_ms: :positive_integer,
    max_reviews: :non_neg_integer,
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          max_steps: pos_integer(),
          max_runtime_ms: pos_integer(),
          max_reviews: non_neg_integer(),
          extensions: map()
        }

  @enforce_keys [:max_steps, :max_runtime_ms, :max_reviews]
  defstruct max_steps: 1, max_runtime_ms: 1_000, max_reviews: 0, extensions: %{}

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.PlanHints.BudgetHints", @fields)

    %__MODULE__{
      max_steps:
        Value.required(attrs, :max_steps, "Citadel.PlanHints.BudgetHints", fn value ->
          Value.positive_integer!(value, "Citadel.PlanHints.BudgetHints.max_steps")
        end),
      max_runtime_ms:
        Value.required(attrs, :max_runtime_ms, "Citadel.PlanHints.BudgetHints", fn value ->
          Value.positive_integer!(value, "Citadel.PlanHints.BudgetHints.max_runtime_ms")
        end),
      max_reviews:
        Value.required(attrs, :max_reviews, "Citadel.PlanHints.BudgetHints", fn value ->
          Value.non_neg_integer!(value, "Citadel.PlanHints.BudgetHints.max_reviews")
        end),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.PlanHints.BudgetHints",
          fn value ->
            Value.json_object!(value, "Citadel.PlanHints.BudgetHints.extensions")
          end,
          %{}
        )
    }
  end

  def dump(%__MODULE__{} = hints) do
    %{
      max_steps: hints.max_steps,
      max_runtime_ms: hints.max_runtime_ms,
      max_reviews: hints.max_reviews,
      extensions: hints.extensions
    }
  end
end

defmodule Citadel.PlanHints.PreferredTopology do
  @moduledoc """
  Preferred-topology hint used inside `Citadel.PlanHints`.
  """

  alias Citadel.ContractCore.Value
  alias Citadel.IntentMappingConstraints

  @schema [
    session_mode: {:enum, IntentMappingConstraints.allowed_session_modes()},
    coordination_mode: {:enum, IntentMappingConstraints.allowed_coordination_modes()},
    routing_hints: {:map, :json},
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          session_mode: :attached | :detached | :stateless,
          coordination_mode: :single_target | :parallel_fanout | :local_only,
          routing_hints: map(),
          extensions: map()
        }

  @enforce_keys [:session_mode, :coordination_mode, :routing_hints]
  defstruct session_mode: :attached,
            coordination_mode: :single_target,
            routing_hints: %{},
            extensions: %{}

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.PlanHints.PreferredTopology", @fields)

    %__MODULE__{
      session_mode:
        Value.required(attrs, :session_mode, "Citadel.PlanHints.PreferredTopology", fn value ->
          Value.enum!(
            value,
            IntentMappingConstraints.allowed_session_modes(),
            "Citadel.PlanHints.PreferredTopology.session_mode"
          )
        end),
      coordination_mode:
        Value.required(
          attrs,
          :coordination_mode,
          "Citadel.PlanHints.PreferredTopology",
          fn value ->
            Value.enum!(
              value,
              IntentMappingConstraints.allowed_coordination_modes(),
              "Citadel.PlanHints.PreferredTopology.coordination_mode"
            )
          end
        ),
      routing_hints:
        Value.required(attrs, :routing_hints, "Citadel.PlanHints.PreferredTopology", fn value ->
          Value.json_object!(value, "Citadel.PlanHints.PreferredTopology.routing_hints")
        end),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.PlanHints.PreferredTopology",
          fn value ->
            Value.json_object!(value, "Citadel.PlanHints.PreferredTopology.extensions")
          end,
          %{}
        )
    }
  end

  def dump(%__MODULE__{} = topology) do
    %{
      session_mode: topology.session_mode,
      coordination_mode: topology.coordination_mode,
      routing_hints: topology.routing_hints,
      extensions: topology.extensions
    }
  end
end

defmodule Citadel.PlanHints do
  @moduledoc """
  Advisory plan shaping hints attached to structured ingress.
  """

  alias Citadel.ContractCore.Value
  alias Citadel.IntentEnvelope.TargetHint
  alias Citadel.PlanHints.BudgetHints
  alias Citadel.PlanHints.CandidateStep
  alias Citadel.PlanHints.PreferredTopology

  @schema [
    candidate_steps: {:list, {:struct, CandidateStep}},
    preferred_targets: {:list, {:struct, TargetHint}},
    preferred_topology: {:struct, PreferredTopology},
    budget_hints: {:struct, BudgetHints},
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          candidate_steps: [CandidateStep.t()],
          preferred_targets: [TargetHint.t()],
          preferred_topology: PreferredTopology.t() | nil,
          budget_hints: BudgetHints.t() | nil,
          extensions: map()
        }

  @enforce_keys []
  defstruct candidate_steps: [],
            preferred_targets: [],
            preferred_topology: nil,
            budget_hints: nil,
            extensions: %{}

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.PlanHints", @fields)

    %__MODULE__{
      candidate_steps:
        Value.optional(
          attrs,
          :candidate_steps,
          "Citadel.PlanHints",
          fn value ->
            Value.list!(value, "Citadel.PlanHints.candidate_steps", fn item ->
              Value.module!(item, CandidateStep, "Citadel.PlanHints.candidate_steps")
            end)
          end,
          []
        ),
      preferred_targets:
        Value.optional(
          attrs,
          :preferred_targets,
          "Citadel.PlanHints",
          fn value ->
            Value.list!(value, "Citadel.PlanHints.preferred_targets", fn item ->
              Value.module!(item, TargetHint, "Citadel.PlanHints.preferred_targets")
            end)
          end,
          []
        ),
      preferred_topology:
        Value.optional(
          attrs,
          :preferred_topology,
          "Citadel.PlanHints",
          fn value ->
            Value.module!(value, PreferredTopology, "Citadel.PlanHints.preferred_topology")
          end,
          nil
        ),
      budget_hints:
        Value.optional(
          attrs,
          :budget_hints,
          "Citadel.PlanHints",
          fn value ->
            Value.module!(value, BudgetHints, "Citadel.PlanHints.budget_hints")
          end,
          nil
        ),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.PlanHints",
          fn value ->
            Value.json_object!(value, "Citadel.PlanHints.extensions")
          end,
          %{}
        )
    }
  end

  def dump(%__MODULE__{} = hints) do
    %{
      candidate_steps: Enum.map(hints.candidate_steps, &CandidateStep.dump/1),
      preferred_targets: Enum.map(hints.preferred_targets, &TargetHint.dump/1),
      preferred_topology: maybe_dump(hints.preferred_topology),
      budget_hints: maybe_dump(hints.budget_hints),
      extensions: hints.extensions
    }
  end

  defp maybe_dump(nil), do: nil
  defp maybe_dump(%module{} = struct), do: module.dump(struct)
end

defmodule Citadel.IntentEnvelope do
  @moduledoc """
  Frozen Wave 3 structured ingress contract for Citadel.
  """

  alias Citadel.ContractCore.Value
  alias Citadel.IntentEnvelope.Constraints
  alias Citadel.IntentEnvelope.DesiredOutcome
  alias Citadel.IntentEnvelope.RiskHint
  alias Citadel.IntentEnvelope.ScopeSelector
  alias Citadel.IntentEnvelope.SuccessCriterion
  alias Citadel.IntentEnvelope.TargetHint
  alias Citadel.PlanHints
  alias Citadel.ResolutionProvenance

  @schema [
    intent_envelope_id: :string,
    scope_selectors: {:list, {:struct, ScopeSelector}},
    desired_outcome: {:struct, DesiredOutcome},
    constraints: {:struct, Constraints},
    risk_hints: {:list, {:struct, RiskHint}},
    success_criteria: {:list, {:struct, SuccessCriterion}},
    target_hints: {:list, {:struct, TargetHint}},
    plan_hints: {:struct, PlanHints},
    resolution_provenance: {:struct, ResolutionProvenance},
    extensions: {:map, :json}
  ]
  @required_fields [
    :intent_envelope_id,
    :scope_selectors,
    :desired_outcome,
    :constraints,
    :risk_hints,
    :success_criteria,
    :target_hints
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          intent_envelope_id: String.t(),
          scope_selectors: [ScopeSelector.t()],
          desired_outcome: DesiredOutcome.t(),
          constraints: Constraints.t(),
          risk_hints: [RiskHint.t()],
          success_criteria: [SuccessCriterion.t()],
          target_hints: [TargetHint.t()],
          plan_hints: PlanHints.t() | nil,
          resolution_provenance: ResolutionProvenance.t() | nil,
          extensions: map()
        }

  @enforce_keys @required_fields
  defstruct @required_fields ++ [plan_hints: nil, resolution_provenance: nil, extensions: %{}]

  def schema, do: @schema

  def frozen_subschemas do
    %{
      scope_selector: ScopeSelector.schema(),
      desired_outcome: DesiredOutcome.schema(),
      constraints: Constraints.schema(),
      risk_hint: RiskHint.schema(),
      success_criterion: SuccessCriterion.schema(),
      target_hint: TargetHint.schema(),
      plan_hints: PlanHints.schema()
    }
  end

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.IntentEnvelope", @fields)

    envelope = %__MODULE__{
      intent_envelope_id:
        Value.required(attrs, :intent_envelope_id, "Citadel.IntentEnvelope", fn value ->
          Value.string!(value, "Citadel.IntentEnvelope.intent_envelope_id")
        end),
      scope_selectors:
        Value.required(attrs, :scope_selectors, "Citadel.IntentEnvelope", fn value ->
          Value.list!(
            value,
            "Citadel.IntentEnvelope.scope_selectors",
            fn item ->
              Value.module!(item, ScopeSelector, "Citadel.IntentEnvelope.scope_selectors")
            end,
            allow_empty?: false
          )
        end),
      desired_outcome:
        Value.required(attrs, :desired_outcome, "Citadel.IntentEnvelope", fn value ->
          Value.module!(value, DesiredOutcome, "Citadel.IntentEnvelope.desired_outcome")
        end),
      constraints:
        Value.required(attrs, :constraints, "Citadel.IntentEnvelope", fn value ->
          Value.module!(value, Constraints, "Citadel.IntentEnvelope.constraints")
        end),
      risk_hints:
        Value.required(attrs, :risk_hints, "Citadel.IntentEnvelope", fn value ->
          Value.list!(value, "Citadel.IntentEnvelope.risk_hints", fn item ->
            Value.module!(item, RiskHint, "Citadel.IntentEnvelope.risk_hints")
          end)
        end),
      success_criteria:
        Value.required(attrs, :success_criteria, "Citadel.IntentEnvelope", fn value ->
          Value.list!(
            value,
            "Citadel.IntentEnvelope.success_criteria",
            fn item ->
              Value.module!(item, SuccessCriterion, "Citadel.IntentEnvelope.success_criteria")
            end,
            allow_empty?: false
          )
        end),
      target_hints:
        Value.required(attrs, :target_hints, "Citadel.IntentEnvelope", fn value ->
          Value.list!(value, "Citadel.IntentEnvelope.target_hints", fn item ->
            Value.module!(item, TargetHint, "Citadel.IntentEnvelope.target_hints")
          end)
        end),
      plan_hints:
        Value.optional(
          attrs,
          :plan_hints,
          "Citadel.IntentEnvelope",
          fn value ->
            Value.module!(value, PlanHints, "Citadel.IntentEnvelope.plan_hints")
          end,
          nil
        ),
      resolution_provenance:
        Value.optional(
          attrs,
          :resolution_provenance,
          "Citadel.IntentEnvelope",
          fn value ->
            Value.module!(
              value,
              ResolutionProvenance,
              "Citadel.IntentEnvelope.resolution_provenance"
            )
          end,
          nil
        ),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.IntentEnvelope",
          fn value ->
            Value.json_object!(value, "Citadel.IntentEnvelope.extensions")
          end,
          %{}
        )
    }

    if Map.has_key?(attrs, "intent") do
      raise ArgumentError,
            "Citadel.IntentEnvelope must not carry raw intent strings at the kernel boundary"
    end

    envelope
  end

  def dump(%__MODULE__{} = envelope) do
    %{
      intent_envelope_id: envelope.intent_envelope_id,
      scope_selectors: Enum.map(envelope.scope_selectors, &ScopeSelector.dump/1),
      desired_outcome: DesiredOutcome.dump(envelope.desired_outcome),
      constraints: Constraints.dump(envelope.constraints),
      risk_hints: Enum.map(envelope.risk_hints, &RiskHint.dump/1),
      success_criteria: Enum.map(envelope.success_criteria, &SuccessCriterion.dump/1),
      target_hints: Enum.map(envelope.target_hints, &TargetHint.dump/1),
      plan_hints: maybe_dump(envelope.plan_hints),
      resolution_provenance: maybe_dump(envelope.resolution_provenance),
      extensions: envelope.extensions
    }
  end

  defp maybe_dump(nil), do: nil
  defp maybe_dump(%module{} = struct), do: module.dump(struct)
end
