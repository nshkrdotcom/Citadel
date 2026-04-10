defmodule Citadel.AuthorityContract do
  @moduledoc """
  Packet-aligned ownership surface for `core/authority_contract`.
  """

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
    status: :wave_1_skeleton,
    owns: [:authority_decision_v1, :packet_versioning, :contract_fixtures],
    internal_dependencies: [:citadel_contract_core],
    external_dependencies: []
  }

  @spec required_fields() :: [atom()]
  def required_fields, do: @required_fields

  @spec manifest() :: map()
  def manifest, do: @manifest
end
