defmodule Citadel.AuthorityContract.GovernedEffectAuthorityRequest do
  @moduledoc """
  Authority request contract for one proposed governed effect.
  """

  alias Citadel.ContractCore.Value

  @required_fields [:tenant_ref, :actor_ref, :effect_type, :operation_type]
  @optional_fields [
    :request_ref,
    :installation_ref,
    :effect_ref,
    :resource_class,
    :side_effect_class,
    :target_refs,
    :budget_refs,
    :residency_refs,
    :extensions
  ]
  @fields @required_fields ++ @optional_fields

  @enforce_keys @required_fields
  defstruct @fields

  @type t :: %__MODULE__{
          tenant_ref: String.t(),
          actor_ref: String.t(),
          effect_type: String.t(),
          operation_type: String.t(),
          request_ref: String.t() | nil,
          installation_ref: String.t() | nil,
          effect_ref: String.t() | nil,
          resource_class: String.t() | nil,
          side_effect_class: String.t(),
          target_refs: [String.t()],
          budget_refs: [String.t()],
          residency_refs: [String.t()],
          extensions: map()
        }

  @spec fields() :: [atom()]
  def fields, do: @fields

  @spec new(t() | map() | keyword()) :: {:ok, t()} | {:error, Exception.t()}
  def new(%__MODULE__{} = request), do: new(dump(request))

  def new(attrs) do
    {:ok, new!(attrs)}
  rescue
    error in ArgumentError -> {:error, error}
  end

  @spec new!(t() | map() | keyword()) :: t()
  def new!(%__MODULE__{} = request), do: new!(dump(request))

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.GovernedEffectAuthorityRequest", @fields)

    %__MODULE__{
      tenant_ref: required_string(attrs, :tenant_ref),
      actor_ref: required_string(attrs, :actor_ref),
      effect_type: required_string(attrs, :effect_type),
      operation_type: required_string(attrs, :operation_type),
      request_ref: optional_string(attrs, :request_ref),
      installation_ref: optional_string(attrs, :installation_ref),
      effect_ref: optional_string(attrs, :effect_ref),
      resource_class: optional_string(attrs, :resource_class),
      side_effect_class: optional_string(attrs, :side_effect_class, "none"),
      target_refs: optional_strings(attrs, :target_refs),
      budget_refs: optional_strings(attrs, :budget_refs),
      residency_refs: optional_strings(attrs, :residency_refs),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.GovernedEffectAuthorityRequest",
          fn value ->
            Value.json_object!(value, "Citadel.GovernedEffectAuthorityRequest.extensions")
          end,
          %{}
        )
    }
  end

  @spec dump(t()) :: map()
  def dump(%__MODULE__{} = request) do
    %{
      tenant_ref: request.tenant_ref,
      actor_ref: request.actor_ref,
      effect_type: request.effect_type,
      operation_type: request.operation_type,
      request_ref: request.request_ref,
      installation_ref: request.installation_ref,
      effect_ref: request.effect_ref,
      resource_class: request.resource_class,
      side_effect_class: request.side_effect_class,
      target_refs: request.target_refs,
      budget_refs: request.budget_refs,
      residency_refs: request.residency_refs,
      extensions: request.extensions
    }
  end

  defp required_string(attrs, field) do
    Value.required(attrs, field, "Citadel.GovernedEffectAuthorityRequest", fn value ->
      Value.string!(value, "Citadel.GovernedEffectAuthorityRequest.#{field}")
    end)
  end

  defp optional_string(attrs, field, default \\ nil) do
    Value.optional(
      attrs,
      field,
      "Citadel.GovernedEffectAuthorityRequest",
      fn value -> Value.string!(value, "Citadel.GovernedEffectAuthorityRequest.#{field}") end,
      default
    )
  end

  defp optional_strings(attrs, field) do
    Value.optional(
      attrs,
      field,
      "Citadel.GovernedEffectAuthorityRequest",
      fn value ->
        Value.unique_strings!(value, "Citadel.GovernedEffectAuthorityRequest.#{field}")
      end,
      []
    )
  end
end
