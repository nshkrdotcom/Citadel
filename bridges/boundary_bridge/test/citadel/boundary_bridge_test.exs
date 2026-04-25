defmodule Citadel.BoundaryBridgeTest do
  use ExUnit.Case, async: true

  alias Citadel.AttachGrant.V1, as: AttachGrantV1
  alias Citadel.AuthorityContract.AuthorityDecision.V1, as: AuthorityDecisionV1
  alias Citadel.BoundaryBridge
  alias Citadel.BoundaryIntent
  alias Citadel.BoundaryLeaseView
  alias Citadel.ExecutionGovernanceCompiler
  alias Citadel.TopologyIntent

  defmodule Downstream do
    def submit_boundary_intent(projection) do
      send(Process.get(:boundary_bridge_test_pid), {:boundary_projection, projection})
      {:ok, "boundary-receipt"}
    end
  end

  setup do
    Process.put(:boundary_bridge_test_pid, self())
    :ok
  end

  test "projects boundary intent separately from signal normalization and normalizes attach-side facts" do
    bridge = BoundaryBridge.new!(downstream: Downstream)

    boundary_intent =
      BoundaryIntent.new!(%{
        boundary_class: "workspace_session",
        trust_profile: "trusted_operator",
        workspace_profile: "project_workspace",
        resource_profile: "standard",
        requested_attach_mode: "fresh_or_reuse",
        requested_ttl_ms: 30_000,
        extensions: %{}
      })

    assert {:ok, "boundary-receipt", bridge} =
             BoundaryBridge.submit_boundary_intent(bridge, boundary_intent, %{
               session_id: "sess-1",
               tenant_id: "tenant-1",
               target_id: "target-1",
               authority_packet: authority_packet(),
               execution_governance: execution_governance(boundary_intent)
             })

    assert_receive {:boundary_projection, projection}
    assert projection["boundary_intent"]["boundary_class"] == "workspace_session"
    assert projection["execution_governance"]["sandbox"]["level"] == "standard"

    assert {:ok, %AttachGrantV1{} = _grant, ^bridge} =
             BoundaryBridge.normalize_attach_grant(bridge, %{
               contract_version: "v1",
               attach_grant_id: "grant-1",
               boundary_session_id: "boundary-session-1",
               boundary_ref: "boundary-ref-1",
               session_id: "sess-1",
               granted_at: ~U[2026-04-10 10:00:00Z],
               expires_at: ~U[2026-04-10 10:10:00Z],
               credential_handle_refs: [],
               extensions: %{}
             })

    assert {:ok, %BoundaryLeaseView{staleness_status: :fresh}, ^bridge} =
             BoundaryBridge.normalize_boundary_lease(bridge, %{
               boundary_ref: "boundary-ref-1",
               last_heartbeat_at: ~U[2026-04-10 10:00:00Z],
               expires_at: ~U[2026-04-10 10:10:00Z],
               staleness_status: :fresh,
               lease_epoch: 1,
               extensions: %{}
             })
  end

  defp authority_packet do
    AuthorityDecisionV1.new!(%{
      contract_version: "v1",
      decision_id: "decision-boundary-1",
      tenant_id: "tenant-1",
      request_id: "req-1",
      policy_version: "policy-1",
      boundary_class: "workspace_session",
      trust_profile: "trusted_operator",
      approval_profile: "approval_optional",
      egress_profile: "restricted",
      workspace_profile: "project_workspace",
      resource_profile: "standard",
      decision_hash: String.duplicate("a", 64),
      extensions: %{"citadel" => %{}}
    })
  end

  defp topology_intent do
    TopologyIntent.new!(%{
      topology_intent_id: "topology-boundary-1",
      session_mode: "attached",
      routing_hints: %{"execution_intent_family" => "process"},
      coordination_mode: "single_target",
      topology_epoch: 1,
      extensions: %{}
    })
  end

  defp execution_governance(boundary_intent) do
    ExecutionGovernanceCompiler.compile!(
      authority_packet(),
      boundary_intent,
      topology_intent(),
      execution_governance_id: "execgov-boundary-1",
      sandbox_level: "standard",
      sandbox_egress: "restricted",
      sandbox_approvals: "auto",
      acceptable_attestation: ["local-erlexec-weak"],
      allowed_tools: ["write_patch"],
      file_scope_ref: "workspace://project/main",
      logical_workspace_ref: "workspace://project/main",
      workspace_mutability: "read_write",
      execution_family: "process",
      placement_intent: "host_local",
      target_kind: "workspace",
      allowed_operations: ["write_patch"],
      effect_classes: []
    )
  end
end
