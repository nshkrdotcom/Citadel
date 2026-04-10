defmodule Citadel.Conformance.WorkspaceSkeletonTest do
  use ExUnit.Case, async: true

  test "tracks the packet-defined core package seams" do
    assert Citadel.ContractCore.manifest().status == :wave_1_skeleton
    assert :decision_hash in Citadel.AuthorityContract.required_fields()
    assert Citadel.ObservabilityContract.telemetry_prefix() == [:citadel]
    assert Citadel.PolicyPacks.selection_inputs() == [:tenant_id, :scope_selector, :policy_epoch]
    assert Citadel.Core.shared_contract_strategy() == :explicit_placeholder
    assert Citadel.Runtime.manifest().package == :citadel_runtime

    assert Citadel.Conformance.manifest().external_dependencies == [
             :jido_integration_v2_contracts
           ]
  end
end
