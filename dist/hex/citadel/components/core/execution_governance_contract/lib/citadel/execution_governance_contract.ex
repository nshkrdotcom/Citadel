defmodule Citadel.ExecutionGovernanceContract do
  @moduledoc """
  Packet-aligned ownership surface for the Brain-to-Spine execution-governance packet.
  """

  alias Citadel.ExecutionGovernance.V1

  @required_fields [
    :contract_version,
    :execution_governance_id,
    :authority_ref,
    :sandbox,
    :boundary,
    :topology,
    :workspace,
    :resources,
    :placement,
    :operations,
    :extensions
  ]

  @manifest %{
    package: :citadel_execution_governance_contract,
    layer: :core,
    status: :wave_10_data_layer_frozen,
    owns: [:execution_governance_v1, :packet_versioning, :contract_fixtures],
    internal_dependencies: [:citadel_contract_core],
    external_dependencies: []
  }

  @extensions_namespaces ["citadel"]

  @spec required_fields() :: [atom()]
  def required_fields, do: @required_fields

  @spec execution_governance_module() :: module()
  def execution_governance_module, do: V1

  @spec contract_version() :: String.t()
  def contract_version, do: V1.contract_version()

  @spec packet_name() :: String.t()
  def packet_name, do: V1.packet_name()

  @spec versioning_rule() :: atom()
  def versioning_rule, do: :explicit_successor_required_for_field_or_semantic_change

  @spec extensions_namespaces() :: [String.t()]
  def extensions_namespaces, do: @extensions_namespaces

  @spec manifest() :: map()
  def manifest, do: @manifest
end
