defmodule Citadel.ExecutionGovernance.V1 do
  @moduledoc """
  Frozen `ExecutionGovernance.v1` brain-authored packet.

  This packet compiles the Brain-authored execution and sandbox posture into a
  typed lower handoff without collapsing provider or backend details into the
  Brain boundary.
  """

  alias Citadel.ContractCore.AttrMap
  alias Citadel.ContractCore.CanonicalJson

  @packet_name "ExecutionGovernance.v1"
  @contract_version "v1"
  @extensions_namespaces ["citadel"]

  @sandbox_levels ["strict", "standard", "none"]
  @egress_policies ["blocked", "restricted", "open"]
  @approval_modes ["manual", "auto", "none"]
  @workspace_mutabilities ["read_only", "read_write", "ephemeral"]
  @execution_families ["process", "http", "json_rpc", "service"]
  @placement_intents ["host_local", "remote_scope", "remote_workspace", "ephemeral_session"]
  @session_modes ["attached", "detached", "stateless"]
  @coordination_modes ["single_target", "parallel_fanout", "local_only"]

  @schema [
    contract_version: {:literal, @contract_version},
    execution_governance_id: :string,
    authority_ref: {:map, :json},
    sandbox: {:map, :json},
    boundary: {:map, :json},
    topology: {:map, :json},
    workspace: {:map, :json},
    resources: {:map, :json},
    placement: {:map, :json},
    operations: {:map, :json},
    extensions: {:map, :citadel_namespaced_json}
  ]
  @required_fields Keyword.keys(@schema)

  @type authority_ref_t :: %{
          required(String.t()) => CanonicalJson.value()
        }

  @type sandbox_t :: %{
          required(String.t()) => CanonicalJson.value()
        }

  @type boundary_t :: %{
          required(String.t()) => CanonicalJson.value()
        }

  @type topology_t :: %{
          required(String.t()) => CanonicalJson.value()
        }

  @type workspace_t :: %{
          required(String.t()) => CanonicalJson.value()
        }

  @type resources_t :: %{
          required(String.t()) => CanonicalJson.value()
        }

  @type placement_t :: %{
          required(String.t()) => CanonicalJson.value()
        }

  @type operations_t :: %{
          required(String.t()) => CanonicalJson.value()
        }

  @type t :: %__MODULE__{
          contract_version: String.t(),
          execution_governance_id: String.t(),
          authority_ref: authority_ref_t(),
          sandbox: sandbox_t(),
          boundary: boundary_t(),
          topology: topology_t(),
          workspace: workspace_t(),
          resources: resources_t(),
          placement: placement_t(),
          operations: operations_t(),
          extensions: %{required(String.t()) => CanonicalJson.value()}
        }

  @enforce_keys @required_fields
  defstruct @required_fields

  @spec packet_name() :: String.t()
  def packet_name, do: @packet_name

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

  @spec schema() :: keyword()
  def schema, do: @schema

  @spec required_fields() :: [atom()]
  def required_fields, do: @required_fields

  @spec extensions_namespaces() :: [String.t()]
  def extensions_namespaces, do: @extensions_namespaces

  @spec versioning_rule() :: atom()
  def versioning_rule, do: :explicit_successor_required_for_field_or_semantic_change

  @spec new(t() | map() | keyword()) :: {:ok, t()} | {:error, Exception.t()}
  def new(%__MODULE__{} = packet), do: normalize(packet)

  def new(attrs) do
    {:ok, build!(attrs)}
  rescue
    error in ArgumentError -> {:error, error}
  end

  @spec new!(t() | map() | keyword()) :: t()
  def new!(%__MODULE__{} = packet) do
    case normalize(packet) do
      {:ok, normalized} -> normalized
      {:error, %ArgumentError{} = error} -> raise error
    end
  end

  def new!(attrs), do: build!(attrs)

  @spec dump(t()) :: map()
  def dump(%__MODULE__{} = packet) do
    %{
      contract_version: packet.contract_version,
      execution_governance_id: packet.execution_governance_id,
      authority_ref: packet.authority_ref,
      sandbox: packet.sandbox,
      boundary: packet.boundary,
      topology: packet.topology,
      workspace: packet.workspace,
      resources: packet.resources,
      placement: packet.placement,
      operations: packet.operations,
      extensions: packet.extensions
    }
  end

  defp build!(attrs) do
    attrs = AttrMap.normalize!(attrs, "#{@packet_name} attrs")

    %__MODULE__{
      contract_version:
        attrs
        |> AttrMap.fetch!(:contract_version, @packet_name)
        |> validate_contract_version!(),
      execution_governance_id:
        attrs
        |> AttrMap.fetch!(:execution_governance_id, @packet_name)
        |> validate_non_empty_string!(:execution_governance_id),
      authority_ref:
        attrs
        |> AttrMap.fetch!(:authority_ref, @packet_name)
        |> validate_authority_ref!(),
      sandbox:
        attrs
        |> AttrMap.fetch!(:sandbox, @packet_name)
        |> validate_sandbox!(),
      boundary:
        attrs
        |> AttrMap.fetch!(:boundary, @packet_name)
        |> validate_boundary!(),
      topology:
        attrs
        |> AttrMap.fetch!(:topology, @packet_name)
        |> validate_topology!(),
      workspace:
        attrs
        |> AttrMap.fetch!(:workspace, @packet_name)
        |> validate_workspace!(),
      resources:
        attrs
        |> AttrMap.fetch!(:resources, @packet_name)
        |> validate_resources!(),
      placement:
        attrs
        |> AttrMap.fetch!(:placement, @packet_name)
        |> validate_placement!(),
      operations:
        attrs
        |> AttrMap.fetch!(:operations, @packet_name)
        |> validate_operations!(),
      extensions:
        attrs
        |> AttrMap.fetch!(:extensions, @packet_name)
        |> validate_extensions!("#{@packet_name}.extensions")
    }
  end

  defp normalize(%__MODULE__{} = packet) do
    {:ok,
     %__MODULE__{
       contract_version: validate_contract_version!(packet.contract_version),
       execution_governance_id:
         validate_non_empty_string!(packet.execution_governance_id, :execution_governance_id),
       authority_ref: validate_authority_ref!(packet.authority_ref),
       sandbox: validate_sandbox!(packet.sandbox),
       boundary: validate_boundary!(packet.boundary),
       topology: validate_topology!(packet.topology),
       workspace: validate_workspace!(packet.workspace),
       resources: validate_resources!(packet.resources),
       placement: validate_placement!(packet.placement),
       operations: validate_operations!(packet.operations),
       extensions: validate_extensions!(packet.extensions, "#{@packet_name}.extensions")
     }}
  rescue
    error in ArgumentError -> {:error, error}
  end

  defp validate_contract_version!(value) when value == @contract_version, do: value

  defp validate_contract_version!(value) do
    raise ArgumentError,
          "#{@packet_name}.contract_version must be #{@contract_version}, got: #{inspect(value)}"
  end

  defp validate_authority_ref!(value) do
    normalized = validate_json_object!(value, "#{@packet_name}.authority_ref")

    %{
      "decision_id" => required_object_string!(normalized, "decision_id", "authority_ref"),
      "policy_version" => required_object_string!(normalized, "policy_version", "authority_ref"),
      "decision_hash" => required_object_string!(normalized, "decision_hash", "authority_ref")
    }
  end

  defp validate_sandbox!(value) do
    normalized = validate_json_object!(value, "#{@packet_name}.sandbox")

    %{
      "level" => required_enum!(normalized, "level", @sandbox_levels, "sandbox"),
      "egress" => required_enum!(normalized, "egress", @egress_policies, "sandbox"),
      "approvals" => required_enum!(normalized, "approvals", @approval_modes, "sandbox"),
      "allowed_tools" => required_string_list!(normalized, "allowed_tools", "sandbox"),
      "file_scope_ref" => required_object_string!(normalized, "file_scope_ref", "sandbox"),
      "file_scope_hint" => optional_object_string(normalized, "file_scope_hint", "sandbox")
    }
  end

  defp validate_boundary!(value) do
    normalized = validate_json_object!(value, "#{@packet_name}.boundary")

    %{
      "boundary_class" => required_object_string!(normalized, "boundary_class", "boundary"),
      "trust_profile" => required_object_string!(normalized, "trust_profile", "boundary"),
      "requested_attach_mode" =>
        required_object_string!(normalized, "requested_attach_mode", "boundary"),
      "requested_ttl_ms" =>
        required_object_non_neg_integer!(normalized, "requested_ttl_ms", "boundary")
    }
  end

  defp validate_topology!(value) do
    normalized = validate_json_object!(value, "#{@packet_name}.topology")

    %{
      "topology_intent_id" =>
        required_object_string!(normalized, "topology_intent_id", "topology"),
      "session_mode" => required_enum!(normalized, "session_mode", @session_modes, "topology"),
      "coordination_mode" =>
        required_enum!(normalized, "coordination_mode", @coordination_modes, "topology"),
      "topology_epoch" =>
        required_object_non_neg_integer!(normalized, "topology_epoch", "topology"),
      "routing_hints" => required_object_json_object!(normalized, "routing_hints", "topology")
    }
  end

  defp validate_workspace!(value) do
    normalized = validate_json_object!(value, "#{@packet_name}.workspace")

    %{
      "workspace_profile" =>
        required_object_string!(normalized, "workspace_profile", "workspace"),
      "logical_workspace_ref" =>
        required_object_string!(normalized, "logical_workspace_ref", "workspace"),
      "mutability" =>
        required_enum!(normalized, "mutability", @workspace_mutabilities, "workspace")
    }
  end

  defp validate_resources!(value) do
    normalized = validate_json_object!(value, "#{@packet_name}.resources")

    %{
      "resource_profile" => required_object_string!(normalized, "resource_profile", "resources"),
      "cpu_class" => optional_object_string(normalized, "cpu_class", "resources"),
      "memory_class" => optional_object_string(normalized, "memory_class", "resources"),
      "wall_clock_budget_ms" =>
        optional_object_non_neg_integer(normalized, "wall_clock_budget_ms", "resources")
    }
  end

  defp validate_placement!(value) do
    normalized = validate_json_object!(value, "#{@packet_name}.placement")

    %{
      "execution_family" =>
        required_enum!(normalized, "execution_family", @execution_families, "placement"),
      "placement_intent" =>
        required_enum!(normalized, "placement_intent", @placement_intents, "placement"),
      "target_kind" => required_object_string!(normalized, "target_kind", "placement"),
      "node_affinity" => optional_object_string(normalized, "node_affinity", "placement")
    }
  end

  defp validate_operations!(value) do
    normalized = validate_json_object!(value, "#{@packet_name}.operations")

    %{
      "allowed_operations" =>
        required_non_empty_string_list!(normalized, "allowed_operations", "operations"),
      "effect_classes" => required_string_list!(normalized, "effect_classes", "operations")
    }
  end

  defp validate_extensions!(value, field) do
    normalized = CanonicalJson.normalize!(value)

    unless is_map(normalized) do
      raise ArgumentError, "#{field} must normalize to a JSON object"
    end

    unknown_namespaces =
      normalized |> Map.keys() |> Enum.sort() |> Kernel.--(@extensions_namespaces)

    if unknown_namespaces != [] do
      raise ArgumentError,
            "#{field} only allows #{@extensions_namespaces |> inspect()} namespaces, got: " <>
              inspect(unknown_namespaces)
    end

    case Map.get(normalized, "citadel") do
      nil ->
        normalized

      nested when is_map(nested) ->
        normalized

      nested ->
        raise ArgumentError,
              "#{field}[\"citadel\"] must be a JSON object, got: #{inspect(nested)}"
    end
  end

  defp validate_non_empty_string!(value, field) when is_binary(value) do
    if String.trim(value) == "" do
      raise ArgumentError, "#{@packet_name}.#{field} must be a non-empty string"
    end

    value
  end

  defp validate_non_empty_string!(value, field) do
    raise ArgumentError,
          "#{@packet_name}.#{field} must be a non-empty string, got: #{inspect(value)}"
  end

  defp validate_json_object!(value, field) do
    normalized = CanonicalJson.normalize!(value)

    if is_map(normalized) do
      normalized
    else
      raise ArgumentError, "#{field} must normalize to a JSON object"
    end
  end

  defp required_object_string!(map, key, section) do
    map
    |> Map.get(key)
    |> validate_non_empty_string!("#{section}.#{key}")
  end

  defp optional_object_string(map, key, section) do
    case Map.get(map, key) do
      nil -> nil
      value -> validate_non_empty_string!(value, "#{section}.#{key}")
    end
  end

  defp required_object_non_neg_integer!(map, key, section) do
    case Map.get(map, key) do
      value when is_integer(value) and value >= 0 ->
        value

      value ->
        raise ArgumentError,
              "#{@packet_name}.#{section}.#{key} must be a non-negative integer, got: #{inspect(value)}"
    end
  end

  defp optional_object_non_neg_integer(map, key, section) do
    case Map.get(map, key) do
      nil ->
        nil

      value when is_integer(value) and value >= 0 ->
        value

      value ->
        raise ArgumentError,
              "#{@packet_name}.#{section}.#{key} must be a non-negative integer, got: #{inspect(value)}"
    end
  end

  defp required_object_json_object!(map, key, section) do
    map
    |> Map.get(key)
    |> validate_json_object!("#{@packet_name}.#{section}.#{key}")
  end

  defp required_enum!(map, key, allowed, section) do
    value = required_object_string!(map, key, section)

    if value in allowed do
      value
    else
      raise ArgumentError,
            "#{@packet_name}.#{section}.#{key} must be one of #{inspect(allowed)}, got: #{inspect(value)}"
    end
  end

  defp required_string_list!(map, key, section) do
    case Map.get(map, key) do
      values when is_list(values) ->
        Enum.map(values, fn value ->
          validate_non_empty_string!(value, "#{section}.#{key}")
        end)

      value ->
        raise ArgumentError,
              "#{@packet_name}.#{section}.#{key} must be a list of strings, got: #{inspect(value)}"
    end
  end

  defp required_non_empty_string_list!(map, key, section) do
    values = required_string_list!(map, key, section)

    if values == [] do
      raise ArgumentError, "#{@packet_name}.#{section}.#{key} must not be empty"
    end

    values
  end
end
