defmodule Citadel.AgentRuntimePolicyProjection do
  @moduledoc """
  Citadel-owned lower-runtime posture for agentic operations.

  The projection is compiled from selected policy and embedded into
  `ExecutionGovernance.v1` extensions. Lower runtime packages may consume this
  exact posture, but they must not broaden it.
  """

  alias Citadel.ContractCore.Value

  @runtime_families [:direct, :session, :process, :http, :jsonrpc, :interop]
  @capability_classes [:model_inference, :tool_call, :skill_invocation]
  @network_postures [:none, :restricted, :approved_egress]
  @artifact_postures [:claim_checked]
  @credential_postures [:lease_only]
  @redaction_postures [:product_safe]

  @schema [
    :projection_ref,
    :authority_ref,
    :tenant_ref,
    :allowed_runtime_families,
    :allowed_capability_classes,
    :denied_capability_classes,
    :skill_allowlist_refs,
    :interop_allowlist_refs,
    :approval_requirements,
    :network_posture,
    :artifact_posture,
    :credential_posture,
    :budget,
    :redaction_posture,
    :revision
  ]

  @type runtime_family :: :direct | :session | :process | :http | :jsonrpc | :interop
  @type capability_class :: :model_inference | :tool_call | :skill_invocation
  @type budget :: %{
          required(:wall_clock_ms) => non_neg_integer(),
          required(:output_bytes) => non_neg_integer(),
          required(:tool_calls) => non_neg_integer()
        }

  @type t :: %__MODULE__{
          projection_ref: String.t(),
          authority_ref: String.t(),
          tenant_ref: String.t(),
          allowed_runtime_families: [runtime_family()],
          allowed_capability_classes: [capability_class()],
          denied_capability_classes: [capability_class()],
          skill_allowlist_refs: [String.t()],
          interop_allowlist_refs: [String.t()],
          approval_requirements: [capability_class()],
          network_posture: :none | :restricted | :approved_egress,
          artifact_posture: :claim_checked,
          credential_posture: :lease_only,
          budget: budget(),
          redaction_posture: :product_safe,
          revision: pos_integer()
        }

  @enforce_keys @schema
  defstruct @schema

  @spec runtime_families() :: [runtime_family()]
  def runtime_families, do: @runtime_families

  @spec capability_classes() :: [capability_class()]
  def capability_classes, do: @capability_classes

  @spec new(t() | map() | keyword()) :: {:ok, t()} | {:error, Exception.t()}
  def new(%__MODULE__{} = projection), do: new(dump(projection))

  def new(attrs) do
    {:ok, new!(attrs)}
  rescue
    error in ArgumentError -> {:error, error}
  end

  @spec new!(t() | map() | keyword()) :: t()
  def new!(%__MODULE__{} = projection), do: new!(dump(projection))

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.AgentRuntimePolicyProjection", @schema)

    %__MODULE__{
      projection_ref:
        required_string(attrs, :projection_ref, "projection_ref", "agent-policy-projection://"),
      authority_ref: required_string(attrs, :authority_ref, "authority_ref", "authority://"),
      tenant_ref: required_string(attrs, :tenant_ref, "tenant_ref", "tenant://"),
      allowed_runtime_families:
        enum_list(
          attrs,
          :allowed_runtime_families,
          @runtime_families,
          "allowed_runtime_families",
          allow_empty?: false
        ),
      allowed_capability_classes:
        enum_list(
          attrs,
          :allowed_capability_classes,
          @capability_classes,
          "allowed_capability_classes",
          allow_empty?: false
        ),
      denied_capability_classes:
        enum_list(
          attrs,
          :denied_capability_classes,
          @capability_classes,
          "denied_capability_classes"
        ),
      skill_allowlist_refs: optional_strings(attrs, :skill_allowlist_refs),
      interop_allowlist_refs: optional_strings(attrs, :interop_allowlist_refs),
      approval_requirements:
        enum_list(attrs, :approval_requirements, @capability_classes, "approval_requirements"),
      network_posture: enum(attrs, :network_posture, @network_postures, "network_posture"),
      artifact_posture: enum(attrs, :artifact_posture, @artifact_postures, "artifact_posture"),
      credential_posture:
        enum(attrs, :credential_posture, @credential_postures, "credential_posture"),
      budget: budget(attrs),
      redaction_posture:
        enum(attrs, :redaction_posture, @redaction_postures, "redaction_posture"),
      revision:
        Value.required(attrs, :revision, "Citadel.AgentRuntimePolicyProjection", fn value ->
          Value.positive_integer!(value, "Citadel.AgentRuntimePolicyProjection.revision")
        end)
    }
  end

  @spec dump(t()) :: map()
  def dump(%__MODULE__{} = projection) do
    %{
      projection_ref: projection.projection_ref,
      authority_ref: projection.authority_ref,
      tenant_ref: projection.tenant_ref,
      allowed_runtime_families: Enum.map(projection.allowed_runtime_families, &Atom.to_string/1),
      allowed_capability_classes:
        Enum.map(projection.allowed_capability_classes, &Atom.to_string/1),
      denied_capability_classes:
        Enum.map(projection.denied_capability_classes, &Atom.to_string/1),
      skill_allowlist_refs: projection.skill_allowlist_refs,
      interop_allowlist_refs: projection.interop_allowlist_refs,
      approval_requirements: Enum.map(projection.approval_requirements, &Atom.to_string/1),
      network_posture: Atom.to_string(projection.network_posture),
      artifact_posture: Atom.to_string(projection.artifact_posture),
      credential_posture: Atom.to_string(projection.credential_posture),
      budget: projection.budget,
      redaction_posture: Atom.to_string(projection.redaction_posture),
      revision: projection.revision
    }
  end

  defp required_string(attrs, field, label, prefix) do
    attrs
    |> Value.required(field, "Citadel.AgentRuntimePolicyProjection", fn value ->
      Value.string!(value, "Citadel.AgentRuntimePolicyProjection.#{label}")
    end)
    |> require_prefix!(label, prefix)
  end

  defp require_prefix!(value, label, prefix) do
    if String.starts_with?(value, prefix) do
      value
    else
      raise ArgumentError,
            "Citadel.AgentRuntimePolicyProjection.#{label} must start with #{inspect(prefix)}"
    end
  end

  defp enum(attrs, field, allowed, label) do
    Value.required(attrs, field, "Citadel.AgentRuntimePolicyProjection", fn value ->
      Value.enum!(value, allowed, "Citadel.AgentRuntimePolicyProjection.#{label}")
    end)
  end

  defp enum_list(attrs, field, allowed, label, opts \\ []) do
    allow_empty? = Keyword.get(opts, :allow_empty?, true)

    values =
      Value.required(attrs, field, "Citadel.AgentRuntimePolicyProjection", fn value ->
        Value.list!(
          value,
          "Citadel.AgentRuntimePolicyProjection.#{label}",
          fn item ->
            Value.enum!(item, allowed, "Citadel.AgentRuntimePolicyProjection.#{label}")
          end,
          allow_empty?: allow_empty?
        )
      end)

    if Enum.uniq(values) == values do
      values
    else
      raise ArgumentError,
            "Citadel.AgentRuntimePolicyProjection.#{label} must not contain duplicates"
    end
  end

  defp optional_strings(attrs, field) do
    Value.required(attrs, field, "Citadel.AgentRuntimePolicyProjection", fn value ->
      Value.unique_strings!(value, "Citadel.AgentRuntimePolicyProjection.#{field}")
    end)
  end

  defp budget(attrs) do
    budget_attrs =
      attrs
      |> Value.required(:budget, "Citadel.AgentRuntimePolicyProjection", fn value ->
        Value.normalize_attrs!(
          value,
          "Citadel.AgentRuntimePolicyProjection.budget",
          [:wall_clock_ms, :output_bytes, :tool_calls]
        )
      end)

    %{
      wall_clock_ms: budget_field(budget_attrs, :wall_clock_ms),
      output_bytes: budget_field(budget_attrs, :output_bytes),
      tool_calls: budget_field(budget_attrs, :tool_calls)
    }
  end

  defp budget_field(attrs, field) do
    Value.required(attrs, field, "Citadel.AgentRuntimePolicyProjection.budget", fn value ->
      Value.non_neg_integer!(value, "Citadel.AgentRuntimePolicyProjection.budget.#{field}")
    end)
  end
end
