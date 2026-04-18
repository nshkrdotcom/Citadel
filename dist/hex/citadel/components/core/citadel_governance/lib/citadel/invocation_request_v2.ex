defmodule Citadel.InvocationRequest.V2 do
  @moduledoc """
  Successor Citadel-owned invoke seam with typed execution-governance carriage.
  """

  alias Citadel.AuthorityContract.AuthorityDecision.V1
  alias Citadel.BoundaryIntent
  alias Citadel.ContractCore.AttrMap
  alias Citadel.ContractCore.CanonicalJson
  alias Citadel.ExecutionGovernance.V1, as: ExecutionGovernanceV1
  alias Citadel.TopologyIntent

  @schema_version 2
  @extensions_namespaces ["citadel"]
  @banned_ingress_payload_keys [
    "raw_input",
    "raw_text",
    "prompt_history",
    "provider_transcript",
    "transcript",
    "raw_nl"
  ]
  @schema [
    schema_version: {:literal, @schema_version},
    invocation_request_id: :string,
    request_id: :string,
    session_id: :string,
    tenant_id: :string,
    trace_id: :string,
    actor_id: :string,
    target_id: :string,
    target_kind: :string,
    selected_step_id: :string,
    allowed_operations: {:list, :string},
    authority_packet: {:struct, V1},
    boundary_intent: {:struct, BoundaryIntent},
    topology_intent: {:struct, TopologyIntent},
    execution_governance: {:struct, ExecutionGovernanceV1},
    extensions: {:map, :citadel_namespaced_json}
  ]
  @required_fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          schema_version: pos_integer(),
          invocation_request_id: String.t(),
          request_id: String.t(),
          session_id: String.t(),
          tenant_id: String.t(),
          trace_id: String.t(),
          actor_id: String.t(),
          target_id: String.t(),
          target_kind: String.t(),
          selected_step_id: String.t(),
          allowed_operations: [String.t(), ...],
          authority_packet: V1.t(),
          boundary_intent: BoundaryIntent.t(),
          topology_intent: TopologyIntent.t(),
          execution_governance: ExecutionGovernanceV1.t(),
          extensions: %{required(String.t()) => CanonicalJson.value()}
        }

  @enforce_keys @required_fields
  defstruct @required_fields

  @spec schema_version() :: pos_integer()
  def schema_version, do: @schema_version

  @spec schema() :: keyword()
  def schema, do: @schema

  @spec required_fields() :: [atom()]
  def required_fields, do: @required_fields

  @spec authority_packet_module() :: module()
  def authority_packet_module, do: V1

  @spec execution_governance_module() :: module()
  def execution_governance_module, do: ExecutionGovernanceV1

  @spec structured_ingress_posture() :: :structured_only
  def structured_ingress_posture, do: :structured_only

  @spec versioning_rule() :: atom()
  def versioning_rule, do: :schema_version_bump_required_for_carrier_shape_change

  @spec new(t() | map() | keyword()) :: {:ok, t()} | {:error, Exception.t()}
  def new(%__MODULE__{} = request), do: normalize(request)

  def new(attrs) do
    {:ok, build!(attrs)}
  rescue
    error in ArgumentError -> {:error, error}
  end

  @spec new!(t() | map() | keyword()) :: t()
  def new!(%__MODULE__{} = request) do
    case normalize(request) do
      {:ok, normalized} -> normalized
      {:error, %ArgumentError{} = error} -> raise error
    end
  end

  def new!(attrs), do: build!(attrs)

  @spec dump(t()) :: map()
  def dump(%__MODULE__{} = request) do
    %{
      schema_version: request.schema_version,
      invocation_request_id: request.invocation_request_id,
      request_id: request.request_id,
      session_id: request.session_id,
      tenant_id: request.tenant_id,
      trace_id: request.trace_id,
      actor_id: request.actor_id,
      target_id: request.target_id,
      target_kind: request.target_kind,
      selected_step_id: request.selected_step_id,
      allowed_operations: request.allowed_operations,
      authority_packet: V1.dump(request.authority_packet),
      boundary_intent: BoundaryIntent.dump(request.boundary_intent),
      topology_intent: TopologyIntent.dump(request.topology_intent),
      execution_governance: ExecutionGovernanceV1.dump(request.execution_governance),
      extensions: request.extensions
    }
  end

  defp build!(attrs) do
    attrs = AttrMap.normalize!(attrs, "Citadel.InvocationRequest.V2 attrs")

    %__MODULE__{
      schema_version:
        attrs
        |> AttrMap.fetch!(:schema_version, "Citadel.InvocationRequest.V2")
        |> validate_schema_version!(),
      invocation_request_id:
        attrs
        |> AttrMap.fetch!(:invocation_request_id, "Citadel.InvocationRequest.V2")
        |> validate_non_empty_string!(:invocation_request_id),
      request_id:
        attrs
        |> AttrMap.fetch!(:request_id, "Citadel.InvocationRequest.V2")
        |> validate_non_empty_string!(:request_id),
      session_id:
        attrs
        |> AttrMap.fetch!(:session_id, "Citadel.InvocationRequest.V2")
        |> validate_non_empty_string!(:session_id),
      tenant_id:
        attrs
        |> AttrMap.fetch!(:tenant_id, "Citadel.InvocationRequest.V2")
        |> validate_non_empty_string!(:tenant_id),
      trace_id:
        attrs
        |> AttrMap.fetch!(:trace_id, "Citadel.InvocationRequest.V2")
        |> validate_non_empty_string!(:trace_id),
      actor_id:
        attrs
        |> AttrMap.fetch!(:actor_id, "Citadel.InvocationRequest.V2")
        |> validate_non_empty_string!(:actor_id),
      target_id:
        attrs
        |> AttrMap.fetch!(:target_id, "Citadel.InvocationRequest.V2")
        |> validate_non_empty_string!(:target_id),
      target_kind:
        attrs
        |> AttrMap.fetch!(:target_kind, "Citadel.InvocationRequest.V2")
        |> validate_non_empty_string!(:target_kind),
      selected_step_id:
        attrs
        |> AttrMap.fetch!(:selected_step_id, "Citadel.InvocationRequest.V2")
        |> validate_non_empty_string!(:selected_step_id),
      allowed_operations:
        attrs
        |> AttrMap.fetch!(:allowed_operations, "Citadel.InvocationRequest.V2")
        |> validate_allowed_operations!(),
      authority_packet:
        attrs
        |> AttrMap.fetch!(:authority_packet, "Citadel.InvocationRequest.V2")
        |> validate_authority_packet!(),
      boundary_intent:
        attrs
        |> AttrMap.fetch!(:boundary_intent, "Citadel.InvocationRequest.V2")
        |> validate_boundary_intent!(),
      topology_intent:
        attrs
        |> AttrMap.fetch!(:topology_intent, "Citadel.InvocationRequest.V2")
        |> validate_topology_intent!(),
      execution_governance:
        attrs
        |> AttrMap.fetch!(:execution_governance, "Citadel.InvocationRequest.V2")
        |> validate_execution_governance!(),
      extensions:
        attrs
        |> AttrMap.fetch!(:extensions, "Citadel.InvocationRequest.V2")
        |> validate_extensions!()
    }
  end

  defp normalize(%__MODULE__{} = request) do
    {:ok,
     %__MODULE__{
       schema_version: validate_schema_version!(request.schema_version),
       invocation_request_id:
         validate_non_empty_string!(request.invocation_request_id, :invocation_request_id),
       request_id: validate_non_empty_string!(request.request_id, :request_id),
       session_id: validate_non_empty_string!(request.session_id, :session_id),
       tenant_id: validate_non_empty_string!(request.tenant_id, :tenant_id),
       trace_id: validate_non_empty_string!(request.trace_id, :trace_id),
       actor_id: validate_non_empty_string!(request.actor_id, :actor_id),
       target_id: validate_non_empty_string!(request.target_id, :target_id),
       target_kind: validate_non_empty_string!(request.target_kind, :target_kind),
       selected_step_id: validate_non_empty_string!(request.selected_step_id, :selected_step_id),
       allowed_operations: validate_allowed_operations!(request.allowed_operations),
       authority_packet: validate_authority_packet!(request.authority_packet),
       boundary_intent: validate_boundary_intent!(request.boundary_intent),
       topology_intent: validate_topology_intent!(request.topology_intent),
       execution_governance: validate_execution_governance!(request.execution_governance),
       extensions: validate_extensions!(request.extensions)
     }}
  rescue
    error in ArgumentError -> {:error, error}
  end

  defp validate_schema_version!(value) when value == @schema_version, do: value

  defp validate_schema_version!(value) do
    raise ArgumentError,
          "Citadel.InvocationRequest.V2.schema_version must be #{@schema_version}, got: #{inspect(value)}"
  end

  defp validate_non_empty_string!(value, field) when is_binary(value) do
    if String.trim(value) == "" do
      raise ArgumentError, "Citadel.InvocationRequest.V2.#{field} must be a non-empty string"
    end

    value
  end

  defp validate_non_empty_string!(value, field) do
    raise ArgumentError,
          "Citadel.InvocationRequest.V2.#{field} must be a non-empty string, got: #{inspect(value)}"
  end

  defp validate_allowed_operations!(value) when is_list(value) do
    normalized =
      Enum.map(value, fn
        operation when is_binary(operation) and operation != "" ->
          operation

        operation ->
          raise ArgumentError,
                "Citadel.InvocationRequest.V2.allowed_operations must be non-empty strings, got: #{inspect(operation)}"
      end)

    if normalized == [] do
      raise ArgumentError, "Citadel.InvocationRequest.V2.allowed_operations must not be empty"
    end

    normalized
  end

  defp validate_allowed_operations!(value) do
    raise ArgumentError,
          "Citadel.InvocationRequest.V2.allowed_operations must be a list of strings, got: #{inspect(value)}"
  end

  defp validate_authority_packet!(%V1{} = packet), do: V1.new!(packet)

  defp validate_authority_packet!(packet) when is_map(packet) or is_list(packet),
    do: V1.new!(packet)

  defp validate_authority_packet!(packet) do
    raise ArgumentError,
          "Citadel.InvocationRequest.V2.authority_packet must be AuthorityDecision.v1, got: #{inspect(packet)}"
  end

  defp validate_boundary_intent!(%BoundaryIntent{} = intent), do: BoundaryIntent.new!(intent)

  defp validate_boundary_intent!(intent) when is_map(intent) or is_list(intent),
    do: BoundaryIntent.new!(intent)

  defp validate_boundary_intent!(intent) do
    raise ArgumentError,
          "Citadel.InvocationRequest.V2.boundary_intent must be Citadel.BoundaryIntent, got: #{inspect(intent)}"
  end

  defp validate_topology_intent!(%TopologyIntent{} = intent), do: TopologyIntent.new!(intent)

  defp validate_topology_intent!(intent) when is_map(intent) or is_list(intent),
    do: TopologyIntent.new!(intent)

  defp validate_topology_intent!(intent) do
    raise ArgumentError,
          "Citadel.InvocationRequest.V2.topology_intent must be Citadel.TopologyIntent, got: #{inspect(intent)}"
  end

  defp validate_execution_governance!(%ExecutionGovernanceV1{} = packet),
    do: ExecutionGovernanceV1.new!(packet)

  defp validate_execution_governance!(packet) when is_map(packet) or is_list(packet),
    do: ExecutionGovernanceV1.new!(packet)

  defp validate_execution_governance!(packet) do
    raise ArgumentError,
          "Citadel.InvocationRequest.V2.execution_governance must be ExecutionGovernance.v1, got: #{inspect(packet)}"
  end

  defp validate_extensions!(value) do
    normalized = CanonicalJson.normalize!(value)

    unless is_map(normalized) do
      raise ArgumentError,
            "Citadel.InvocationRequest.V2.extensions must normalize to a JSON object"
    end

    unknown_namespaces =
      normalized |> Map.keys() |> Enum.sort() |> Kernel.--(@extensions_namespaces)

    if unknown_namespaces != [] do
      raise ArgumentError,
            "Citadel.InvocationRequest.V2.extensions only allows #{@extensions_namespaces |> inspect()} namespaces, got: " <>
              inspect(unknown_namespaces)
    end

    case Map.get(normalized, "citadel") do
      nil ->
        normalized

      nested when is_map(nested) ->
        validate_ingress_provenance!(nested)
        normalized

      nested ->
        raise ArgumentError,
              "Citadel.InvocationRequest.V2.extensions[\"citadel\"] must be a JSON object, got: #{inspect(nested)}"
    end
  end

  defp validate_ingress_provenance!(citadel_extensions) do
    case Map.get(citadel_extensions, "ingress_provenance") do
      nil ->
        :ok

      provenance when is_map(provenance) ->
        offending_keys =
          provenance
          |> Map.keys()
          |> Enum.filter(&(&1 in @banned_ingress_payload_keys))

        if offending_keys != [] do
          raise ArgumentError,
                "Citadel.InvocationRequest.V2.extensions[\"citadel\"][\"ingress_provenance\"] must carry refs or hashes, not raw payload keys: " <>
                  inspect(offending_keys)
        end

      provenance ->
        raise ArgumentError,
              "Citadel.InvocationRequest.V2.extensions[\"citadel\"][\"ingress_provenance\"] must be a JSON object, got: #{inspect(provenance)}"
    end
  end
end
