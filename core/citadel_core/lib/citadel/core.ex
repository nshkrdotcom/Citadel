defmodule Citadel.Core do
  @moduledoc """
  Packet-aligned ownership surface for `core/citadel_core`.
  """

  alias Citadel.AuthorityContract.AuthorityDecision.V1

  @manifest %{
    package: :citadel_core,
    layer: :core,
    status: :wave_2_seam_frozen,
    owns: [
      :pure_values,
      :decision_hash,
      :invocation_request_seam,
      :compilers,
      :reducers,
      :projectors
    ],
    internal_dependencies: [
      :citadel_contract_core,
      :citadel_authority_contract,
      :citadel_observability_contract,
      :citadel_policy_packs
    ],
    external_dependencies: [:jido_integration_v2_contracts]
  }

  @shared_lineage_contracts [
    Jido.Integration.V2.SubjectRef,
    Jido.Integration.V2.EvidenceRef,
    Jido.Integration.V2.GovernanceRef,
    Jido.Integration.V2.ReviewProjection,
    Jido.Integration.V2.DerivedStateAttachment
  ]

  @spec shared_contract_strategy() :: :higher_order_shared_contracts_only
  def shared_contract_strategy, do: :higher_order_shared_contracts_only

  @spec authority_packet_module() :: module()
  def authority_packet_module, do: V1

  @spec invocation_request_module() :: module()
  def invocation_request_module, do: Citadel.InvocationRequest

  @spec structured_ingress_posture() :: :structured_only
  def structured_ingress_posture, do: :structured_only

  @spec shared_lineage_contracts() :: [module(), ...]
  def shared_lineage_contracts, do: @shared_lineage_contracts

  @spec manifest() :: map()
  def manifest, do: @manifest
end
