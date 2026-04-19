defmodule Citadel.AuthorityContract.EnterprisePrecutContractsTest do
  use ExUnit.Case, async: true

  alias Citadel.AuthorityContract

  alias Citadel.{
    AuthorityPacketV2,
    OperatorWorkflowSignalAuthorityV1,
    PermissionDecisionV1,
    PolicyEvidenceRef,
    RejectionClass
  }

  test "exposes the M24 public Citadel contract modules" do
    assert AuthorityPacketV2.packet_name() == "Citadel.AuthorityPacketV2.v1"
    assert PermissionDecisionV1.contract_name() == "Citadel.PermissionDecisionV1.v1"

    assert OperatorWorkflowSignalAuthorityV1.contract_name() ==
             "Citadel.OperatorWorkflowSignalAuthority.v1"

    assert AuthorityContract.operator_workflow_signal_authority_module() ==
             OperatorWorkflowSignalAuthorityV1

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

  test "builds operator workflow signal authority decisions for allow and deny paths" do
    assert {:ok, allow} =
             OperatorWorkflowSignalAuthorityV1.new(%{
               decision_id: "operator-signal-decision-097",
               tenant_ref: "tenant-acme",
               installation_ref: "installation-main",
               workspace_ref: "workspace-main",
               project_ref: "project-main",
               environment_ref: "env-prod",
               principal_ref: "principal-operator",
               operator_ref: "operator-1",
               resource_ref: "resource-workflow-097",
               workflow_id: "workflow-097",
               workflow_run_id: "run-097",
               signal_id: "signal-097",
               signal_name: "operator.cancel",
               signal_version: "operator-cancel.v1",
               signal_effect: "cancel_requested",
               requested_action: "workflow.cancel",
               result: "allow",
               authority_packet_ref: "authpkt-097",
               permission_decision_ref: "decision-097",
               policy_bundle_ref: "policy-pack-097",
               policy_revision: "policy-rev-097",
               idempotency_key: "idem-signal-097",
               trace_id: "trace-097",
               correlation_id: "corr-097",
               release_manifest_ref: "phase4-v6-milestone28",
               decided_at: "2026-04-18T12:00:00Z",
               evidence_refs: ["evidence-097"]
             })

    assert allow.contract_name == "Citadel.OperatorWorkflowSignalAuthority.v1"
    assert allow.result == "allow"

    assert {:ok, deny} =
             OperatorWorkflowSignalAuthorityV1.new(%{
               allow
               | decision_id: "operator-signal-decision-098",
                 signal_id: "signal-098",
                 result: "unregistered_signal",
                 rejection_class: "unauthorized_action",
                 idempotency_key: "idem-signal-098"
             })

    assert deny.result == "unregistered_signal"
    assert deny.rejection_class == "unauthorized_action"
  end
end
