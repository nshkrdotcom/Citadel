defmodule Citadel.AuthorityContract.EnterprisePrecutContractsTest do
  use ExUnit.Case, async: true

  alias Citadel.{
    AuthorityPacketV2,
    PermissionDecisionV1,
    PolicyEvidenceRef,
    RejectionClass
  }

  test "exposes the M24 public Citadel contract modules" do
    assert AuthorityPacketV2.packet_name() == "Citadel.AuthorityPacketV2.v1"
    assert PermissionDecisionV1.contract_name() == "Citadel.PermissionDecisionV1.v1"
    assert RejectionClass.known?("wrong_tenant")
    assert RejectionClass.known?("missing_authority")
  end

  test "builds permission decisions with authority, trace, and evidence refs" do
    assert {:ok, evidence_ref} =
             PolicyEvidenceRef.new(%{
               evidence_ref: "evidence-1",
               tenant_ref: "tenant-acme",
               policy_bundle_ref: "policy-pack-1",
               policy_revision: "policy-rev-1",
               trace_id: "trace-106"
             })

    assert {:ok, decision} =
             PermissionDecisionV1.new(%{
               decision_id: "decision-106",
               decision_version: "v1",
               authority_packet_ref: "authpkt-106",
               tenant_ref: "tenant-acme",
               actor_ref: "principal-operator",
               resource_ref: "resource-work-1",
               action_name: "work.start",
               result: "deny",
               rejection_class: "unauthorized_action",
               policy_bundle_ref: "policy-pack-1",
               policy_revision: "policy-rev-1",
               input_hash: String.duplicate("a", 64),
               decision_hash: String.duplicate("b", 64),
               evidence_refs: [evidence_ref.evidence_ref],
               trace_id: "trace-106",
               decided_at: "2026-04-18T00:00:00Z"
             })

    assert decision.contract_name == "Citadel.PermissionDecisionV1.v1"
    assert decision.result == "deny"
    assert decision.evidence_refs == ["evidence-1"]
  end

  test "permission decisions fail closed when authority scope is missing" do
    assert {:error, {:missing_required_fields, [:authority_packet_ref]}} =
             PermissionDecisionV1.new(%{
               decision_id: "decision-106",
               decision_version: "v1",
               tenant_ref: "tenant-acme",
               actor_ref: "principal-operator",
               resource_ref: "resource-work-1",
               action_name: "work.start",
               result: "deny",
               policy_bundle_ref: "policy-pack-1",
               policy_revision: "policy-rev-1",
               input_hash: String.duplicate("a", 64),
               decision_hash: String.duplicate("b", 64),
               evidence_refs: ["evidence-1"],
               trace_id: "trace-106",
               decided_at: "2026-04-18T00:00:00Z"
             })
  end
end
