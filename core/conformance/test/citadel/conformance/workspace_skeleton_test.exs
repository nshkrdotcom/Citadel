defmodule Citadel.Conformance.WorkspaceSkeletonTest do
  use ExUnit.Case, async: true

  test "tracks the packet-defined wave 2 seam freeze" do
    assert Citadel.ContractCore.manifest().status == :wave_2_seam_frozen
    assert Citadel.AuthorityContract.manifest().status == :wave_2_seam_frozen
    assert Citadel.AuthorityContract.packet_name() == "AuthorityDecision.v1"
    assert Citadel.AuthorityContract.extensions_namespaces() == ["citadel"]
    assert :decision_hash in Citadel.AuthorityContract.required_fields()
    assert Citadel.ObservabilityContract.telemetry_prefix() == [:citadel]
    assert Citadel.PolicyPacks.selection_inputs() == [:tenant_id, :scope_selector, :policy_epoch]
    assert Citadel.Core.shared_contract_strategy() == :higher_order_shared_contracts_only

    assert Citadel.Core.authority_packet_module() ==
             Citadel.AuthorityContract.AuthorityDecision.V1

    assert Citadel.Core.invocation_request_module() == Citadel.InvocationRequest
    assert Citadel.Core.structured_ingress_posture() == :structured_only

    assert Citadel.Core.shared_lineage_contracts() == [
             Jido.Integration.V2.SubjectRef,
             Jido.Integration.V2.EvidenceRef,
             Jido.Integration.V2.GovernanceRef,
             Jido.Integration.V2.ReviewProjection,
             Jido.Integration.V2.DerivedStateAttachment
           ]

    assert Citadel.Runtime.manifest().package == :citadel_runtime

    assert Citadel.InvocationBridge.shared_contract_strategy() ==
             :citadel_invocation_request_entrypoint

    assert Citadel.InvocationBridge.supported_invocation_request_schema_versions() == [1]

    assert_raise ArgumentError, ~r/unsupported Citadel\.InvocationRequest\.schema_version/, fn ->
      Citadel.InvocationBridge.ensure_supported_invocation_request_schema_version!(2)
    end

    assert Citadel.Conformance.manifest().external_dependencies == [
             :jido_integration_v2_contracts
           ]
  end
end
