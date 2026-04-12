defmodule Citadel.ExecutionIntentEnvelopeV2Test do
  use ExUnit.Case, async: true

  alias Citadel.AuthorityContract.AuthorityDecision.V1, as: AuthorityDecisionV1
  alias Citadel.BoundaryIntent
  alias Citadel.ExecutionGovernanceCompiler
  alias Citadel.ExecutionIntentEnvelope.V2
  alias Citadel.HttpExecutionIntent.V1, as: HttpExecutionIntentV1
  alias Citadel.TopologyIntent

  test "freezes the execution intent envelope successor seam with typed execution governance" do
    envelope = V2.new!(envelope_attrs())

    assert V2.contract_version() == "v2"
    assert envelope.execution_governance.execution_governance_id == "execgov-envelope-v2-1"
    assert envelope.execution_intent_family == "http"
    assert %HttpExecutionIntentV1{} = envelope.execution_intent
    assert V2.dump(envelope).execution_governance.placement["execution_family"] == "http"
  end

  defp envelope_attrs do
    %{
      contract_version: "v2",
      intent_envelope_id: "execution-intent:entry-v2-1",
      entry_id: "entry-v2-1",
      causal_group_id: "group-v2-1",
      invocation_request_id: "invoke-v2-1",
      invocation_schema_version: 2,
      request_id: "req-v2-1",
      session_id: "sess-v2-1",
      tenant_id: "tenant-v2-1",
      trace_id: "trace-v2-1",
      actor_id: "actor-v2-1",
      target_id: "target-v2-1",
      target_kind: "http",
      allowed_operations: ["fetch"],
      authority_packet: authority_packet(),
      boundary_intent: boundary_intent(),
      topology_intent: topology_intent(),
      execution_governance: execution_governance(),
      execution_intent_family: "http",
      execution_intent:
        HttpExecutionIntentV1.new!(%{
          contract_version: "v1",
          method: "POST",
          url: "https://example.test/invoke",
          headers: %{"content-type" => "application/json"},
          body: %{"request" => "payload"},
          extensions: %{}
        }),
      extensions: %{"downstream_scope" => "http:example.test"}
    }
  end

  defp authority_packet do
    AuthorityDecisionV1.new!(%{
      contract_version: "v1",
      decision_id: "decision-envelope-v2-1",
      tenant_id: "tenant-v2-1",
      request_id: "req-v2-1",
      policy_version: "policy-v2-1",
      boundary_class: "workspace_session",
      trust_profile: "trusted_operator",
      approval_profile: "approval_optional",
      egress_profile: "restricted",
      workspace_profile: "project_workspace",
      resource_profile: "standard",
      decision_hash: String.duplicate("b", 64),
      extensions: %{"citadel" => %{}}
    })
  end

  defp boundary_intent do
    BoundaryIntent.new!(%{
      boundary_class: "workspace_session",
      trust_profile: "trusted_operator",
      workspace_profile: "project_workspace",
      resource_profile: "standard",
      requested_attach_mode: "fresh_or_reuse",
      requested_ttl_ms: 30_000,
      extensions: %{}
    })
  end

  defp topology_intent do
    TopologyIntent.new!(%{
      topology_intent_id: "topology-envelope-v2-1",
      session_mode: "attached",
      routing_hints: %{"execution_intent_family" => "http"},
      coordination_mode: "single_target",
      topology_epoch: 1,
      extensions: %{}
    })
  end

  defp execution_governance do
    ExecutionGovernanceCompiler.compile!(
      authority_packet(),
      boundary_intent(),
      topology_intent(),
      execution_governance_id: "execgov-envelope-v2-1",
      sandbox_level: "standard",
      sandbox_egress: "restricted",
      sandbox_approvals: "auto",
      allowed_tools: ["fetch_http"],
      file_scope_ref: "workspace://project/main",
      logical_workspace_ref: "workspace://project/main",
      workspace_mutability: "read_write",
      execution_family: "http",
      placement_intent: "host_local",
      target_kind: "http",
      allowed_operations: ["fetch"],
      effect_classes: ["network_http"]
    )
  end
end
