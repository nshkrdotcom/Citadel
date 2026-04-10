defmodule Citadel.TopologyIntent do
  @moduledoc """
  Frozen `TopologyIntent` carrier shape owned by Citadel.
  """

  alias Citadel.ContractCore.AttrMap
  alias Citadel.ContractCore.CanonicalJson

  @schema [
    topology_intent_id: :string,
    session_mode: :string,
    routing_hints: {:map, :json},
    coordination_mode: :string,
    topology_epoch: :non_neg_integer,
    extensions: {:map, :json}
  ]
  @required_fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          topology_intent_id: String.t(),
          session_mode: String.t(),
          routing_hints: %{required(String.t()) => CanonicalJson.value()},
          coordination_mode: String.t(),
          topology_epoch: non_neg_integer(),
          extensions: %{required(String.t()) => CanonicalJson.value()}
        }
  @allowed_session_modes ["attached", "detached", "stateless"]
  @allowed_coordination_modes ["single_target", "parallel_fanout", "local_only"]

  @enforce_keys @required_fields
  defstruct @required_fields

  @spec schema() :: keyword()
  def schema, do: @schema

  @spec required_fields() :: [atom()]
  def required_fields, do: @required_fields

  @spec versioning_rule() :: atom()
  def versioning_rule, do: :schema_version_bump_required_for_carrier_shape_change

  @spec allowed_session_modes() :: [String.t()]
  def allowed_session_modes, do: @allowed_session_modes

  @spec allowed_coordination_modes() :: [String.t()]
  def allowed_coordination_modes, do: @allowed_coordination_modes

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
      topology_intent_id: intent.topology_intent_id,
      session_mode: intent.session_mode,
      routing_hints: intent.routing_hints,
      coordination_mode: intent.coordination_mode,
      topology_epoch: intent.topology_epoch,
      extensions: intent.extensions
    }
  end

  defp build!(attrs) do
    attrs = AttrMap.normalize!(attrs, "Citadel.TopologyIntent attrs")

    %__MODULE__{
      topology_intent_id:
        attrs
        |> AttrMap.fetch!(:topology_intent_id, "Citadel.TopologyIntent")
        |> validate_non_empty_string!(:topology_intent_id),
      session_mode:
        attrs
        |> AttrMap.fetch!(:session_mode, "Citadel.TopologyIntent")
        |> validate_session_mode!(),
      routing_hints:
        attrs
        |> AttrMap.fetch!(:routing_hints, "Citadel.TopologyIntent")
        |> validate_json_object!("Citadel.TopologyIntent.routing_hints"),
      coordination_mode:
        attrs
        |> AttrMap.fetch!(:coordination_mode, "Citadel.TopologyIntent")
        |> validate_coordination_mode!(),
      topology_epoch:
        attrs
        |> AttrMap.fetch!(:topology_epoch, "Citadel.TopologyIntent")
        |> validate_non_neg_integer!(:topology_epoch),
      extensions:
        attrs
        |> AttrMap.fetch!(:extensions, "Citadel.TopologyIntent")
        |> validate_json_object!("Citadel.TopologyIntent.extensions")
    }
  end

  defp normalize(%__MODULE__{} = intent) do
    {:ok,
     %__MODULE__{
       topology_intent_id:
         validate_non_empty_string!(intent.topology_intent_id, :topology_intent_id),
       session_mode: validate_session_mode!(intent.session_mode),
       routing_hints:
         validate_json_object!(intent.routing_hints, "Citadel.TopologyIntent.routing_hints"),
       coordination_mode: validate_coordination_mode!(intent.coordination_mode),
       topology_epoch: validate_non_neg_integer!(intent.topology_epoch, :topology_epoch),
       extensions: validate_json_object!(intent.extensions, "Citadel.TopologyIntent.extensions")
     }}
  rescue
    error in ArgumentError -> {:error, error}
  end

  defp validate_non_empty_string!(value, field) when is_binary(value) do
    if String.trim(value) == "" do
      raise ArgumentError, "Citadel.TopologyIntent.#{field} must be a non-empty string"
    end

    value
  end

  defp validate_non_empty_string!(value, field) do
    raise ArgumentError,
          "Citadel.TopologyIntent.#{field} must be a non-empty string, got: #{inspect(value)}"
  end

  defp validate_non_neg_integer!(value, _field) when is_integer(value) and value >= 0, do: value

  defp validate_non_neg_integer!(value, field) do
    raise ArgumentError,
          "Citadel.TopologyIntent.#{field} must be a non-negative integer, got: #{inspect(value)}"
  end

  defp validate_session_mode!(value) do
    normalized = validate_non_empty_string!(value, :session_mode)

    if normalized in @allowed_session_modes do
      normalized
    else
      raise ArgumentError,
            "Citadel.TopologyIntent.session_mode must be one of #{inspect(@allowed_session_modes)}, got: #{inspect(value)}"
    end
  end

  defp validate_coordination_mode!(value) do
    normalized = validate_non_empty_string!(value, :coordination_mode)

    if normalized in @allowed_coordination_modes do
      normalized
    else
      raise ArgumentError,
            "Citadel.TopologyIntent.coordination_mode must be one of #{inspect(@allowed_coordination_modes)}, got: #{inspect(value)}"
    end
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
