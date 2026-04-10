defmodule Citadel.AuthorityContract do
  @moduledoc """
  Packet-aligned ownership surface for the shared Brain authority packet.
  """

  alias Citadel.AuthorityContract.AuthorityDecision.V1

  @required_fields [
    :contract_version,
    :decision_id,
    :tenant_id,
    :request_id,
    :policy_version,
    :boundary_class,
    :trust_profile,
    :approval_profile,
    :egress_profile,
    :workspace_profile,
    :resource_profile,
    :decision_hash,
    :extensions
  ]

  @manifest %{
    package: :citadel_authority_contract,
    layer: :core,
    status: :wave_2_seam_frozen,
    owns: [:authority_decision_v1, :packet_versioning, :contract_fixtures],
    internal_dependencies: [:citadel_contract_core],
    external_dependencies: []
  }

  @extensions_namespaces ["citadel"]

  @spec required_fields() :: [atom()]
  def required_fields, do: @required_fields

  @spec authority_decision_module() :: module()
  def authority_decision_module, do: V1

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
