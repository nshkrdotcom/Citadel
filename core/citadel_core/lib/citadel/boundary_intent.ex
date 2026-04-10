defmodule Citadel.BoundaryIntent do
  @moduledoc """
  Frozen `BoundaryIntent` carrier shape owned by Citadel.
  """

  alias Citadel.ContractCore.AttrMap
  alias Citadel.ContractCore.CanonicalJson

  @schema [
    boundary_class: :string,
    trust_profile: :string,
    workspace_profile: :string,
    resource_profile: :string,
    requested_attach_mode: :string,
    requested_ttl_ms: :non_neg_integer,
    extensions: {:map, :json}
  ]
  @required_fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          boundary_class: String.t(),
          trust_profile: String.t(),
          workspace_profile: String.t(),
          resource_profile: String.t(),
          requested_attach_mode: String.t(),
          requested_ttl_ms: non_neg_integer(),
          extensions: %{required(String.t()) => CanonicalJson.value()}
        }

  @enforce_keys @required_fields
  defstruct @required_fields

  @spec schema() :: keyword()
  def schema, do: @schema

  @spec required_fields() :: [atom()]
  def required_fields, do: @required_fields

  @spec versioning_rule() :: atom()
  def versioning_rule, do: :schema_version_bump_required_for_carrier_shape_change

  @spec new(t() | map() | keyword()) :: {:ok, t()} | {:error, Exception.t()}
  def new(%__MODULE__{} = intent), do: normalize(intent)

  def new(attrs) do
    {:ok, build!(attrs)}
  rescue
    error in ArgumentError -> {:error, error}
  end

  @spec new!(t() | map() | keyword()) :: t()
  def new!(%__MODULE__{} = intent) do
    case normalize(intent) do
      {:ok, normalized} -> normalized
      {:error, %ArgumentError{} = error} -> raise error
    end
  end

  def new!(attrs), do: build!(attrs)

  @spec dump(t()) :: map()
  def dump(%__MODULE__{} = intent) do
    %{
      boundary_class: intent.boundary_class,
      trust_profile: intent.trust_profile,
      workspace_profile: intent.workspace_profile,
      resource_profile: intent.resource_profile,
      requested_attach_mode: intent.requested_attach_mode,
      requested_ttl_ms: intent.requested_ttl_ms,
      extensions: intent.extensions
    }
  end

  defp build!(attrs) do
    attrs = AttrMap.normalize!(attrs, "Citadel.BoundaryIntent attrs")

    %__MODULE__{
      boundary_class:
        attrs
        |> AttrMap.fetch!(:boundary_class, "Citadel.BoundaryIntent")
        |> validate_non_empty_string!(:boundary_class),
      trust_profile:
        attrs
        |> AttrMap.fetch!(:trust_profile, "Citadel.BoundaryIntent")
        |> validate_non_empty_string!(:trust_profile),
      workspace_profile:
        attrs
        |> AttrMap.fetch!(:workspace_profile, "Citadel.BoundaryIntent")
        |> validate_non_empty_string!(:workspace_profile),
      resource_profile:
        attrs
        |> AttrMap.fetch!(:resource_profile, "Citadel.BoundaryIntent")
        |> validate_non_empty_string!(:resource_profile),
      requested_attach_mode:
        attrs
        |> AttrMap.fetch!(:requested_attach_mode, "Citadel.BoundaryIntent")
        |> validate_non_empty_string!(:requested_attach_mode),
      requested_ttl_ms:
        attrs
        |> AttrMap.fetch!(:requested_ttl_ms, "Citadel.BoundaryIntent")
        |> validate_non_neg_integer!(:requested_ttl_ms),
      extensions:
        attrs
        |> AttrMap.fetch!(:extensions, "Citadel.BoundaryIntent")
        |> validate_json_object!("Citadel.BoundaryIntent.extensions")
    }
  end

  defp normalize(%__MODULE__{} = intent) do
    {:ok,
     %__MODULE__{
       boundary_class: validate_non_empty_string!(intent.boundary_class, :boundary_class),
       trust_profile: validate_non_empty_string!(intent.trust_profile, :trust_profile),
       workspace_profile:
         validate_non_empty_string!(intent.workspace_profile, :workspace_profile),
       resource_profile: validate_non_empty_string!(intent.resource_profile, :resource_profile),
       requested_attach_mode:
         validate_non_empty_string!(intent.requested_attach_mode, :requested_attach_mode),
       requested_ttl_ms: validate_non_neg_integer!(intent.requested_ttl_ms, :requested_ttl_ms),
       extensions: validate_json_object!(intent.extensions, "Citadel.BoundaryIntent.extensions")
     }}
  rescue
    error in ArgumentError -> {:error, error}
  end

  defp validate_non_empty_string!(value, field) when is_binary(value) do
    if String.trim(value) == "" do
      raise ArgumentError, "Citadel.BoundaryIntent.#{field} must be a non-empty string"
    end

    value
  end

  defp validate_non_empty_string!(value, field) do
    raise ArgumentError,
          "Citadel.BoundaryIntent.#{field} must be a non-empty string, got: #{inspect(value)}"
  end

  defp validate_non_neg_integer!(value, _field) when is_integer(value) and value >= 0, do: value

  defp validate_non_neg_integer!(value, field) do
    raise ArgumentError,
          "Citadel.BoundaryIntent.#{field} must be a non-negative integer, got: #{inspect(value)}"
  end

  defp validate_json_object!(value, field) do
    normalized = CanonicalJson.normalize!(value)

    if is_map(normalized) do
      normalized
    else
      raise ArgumentError, "#{field} must normalize to a JSON object"
    end
  end
end
