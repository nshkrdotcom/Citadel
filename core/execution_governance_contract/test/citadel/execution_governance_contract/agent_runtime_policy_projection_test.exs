defmodule Citadel.ExecutionGovernanceContract.AgentRuntimePolicyProjectionTest do
  use ExUnit.Case, async: true

  alias Citadel.AgentRuntimePolicyProjection
  alias Citadel.ExecutionGovernance.V1, as: ExecutionGovernanceV1

  test "normalizes a complete agent runtime policy projection" do
    projection = AgentRuntimePolicyProjection.new!(valid_projection_attrs())

    assert projection.projection_ref == "agent-policy-projection://tenant-1/run-1"
    assert projection.allowed_runtime_families == [:process, :http, :interop]
    assert projection.allowed_capability_classes == [:tool_call, :skill_invocation]
    assert projection.network_posture == :restricted
    assert projection.credential_posture == :lease_only
    assert projection.budget.wall_clock_ms == 60_000

    assert AgentRuntimePolicyProjection.dump(projection) == %{
             projection_ref: "agent-policy-projection://tenant-1/run-1",
             authority_ref: "authority://decision-1",
             tenant_ref: "tenant://tenant-1",
             allowed_runtime_families: ["process", "http", "interop"],
             allowed_capability_classes: ["tool_call", "skill_invocation"],
             denied_capability_classes: [],
             skill_allowlist_refs: ["skill://document-review"],
             interop_allowlist_refs: ["agent-interop://external-reviewer"],
             approval_requirements: ["skill_invocation"],
             network_posture: "restricted",
             artifact_posture: "claim_checked",
             credential_posture: "lease_only",
             budget: %{wall_clock_ms: 60_000, output_bytes: 1_000_000, tool_calls: 20},
             redaction_posture: "product_safe",
             revision: 1
           }
  end

  test "rejects missing projection fields and unsupported runtime families" do
    assert_raise ArgumentError, fn ->
      valid_projection_attrs()
      |> Map.delete(:credential_posture)
      |> AgentRuntimePolicyProjection.new!()
    end

    assert_raise ArgumentError, fn ->
      valid_projection_attrs()
      |> Map.put(:allowed_runtime_families, [:process, :unknown_runtime])
      |> AgentRuntimePolicyProjection.new!()
    end
  end

  test "execution governance extension validates embedded agent runtime projection" do
    packet =
      minimal_execution_governance(%{
        "citadel" => %{
          "agent_runtime_policy_projection" =>
            valid_projection_attrs()
            |> AgentRuntimePolicyProjection.new!()
            |> AgentRuntimePolicyProjection.dump()
        }
      })
      |> ExecutionGovernanceV1.new!()

    assert packet.extensions["citadel"]["agent_runtime_policy_projection"]["credential_posture"] ==
             "lease_only"

    assert_raise ArgumentError, fn ->
      minimal_execution_governance(%{
        "citadel" => %{
          "agent_runtime_policy_projection" => %{
            "projection_ref" => "agent-policy-projection://bad"
          }
        }
      })
      |> ExecutionGovernanceV1.new!()
    end
  end

  defp valid_projection_attrs do
    %{
      projection_ref: "agent-policy-projection://tenant-1/run-1",
      authority_ref: "authority://decision-1",
      tenant_ref: "tenant://tenant-1",
      allowed_runtime_families: [:process, :http, :interop],
      allowed_capability_classes: [:tool_call, :skill_invocation],
      denied_capability_classes: [],
      skill_allowlist_refs: ["skill://document-review"],
      interop_allowlist_refs: ["agent-interop://external-reviewer"],
      approval_requirements: [:skill_invocation],
      network_posture: :restricted,
      artifact_posture: :claim_checked,
      credential_posture: :lease_only,
      budget: %{wall_clock_ms: 60_000, output_bytes: 1_000_000, tool_calls: 20},
      redaction_posture: :product_safe,
      revision: 1
    }
  end

  defp minimal_execution_governance(extensions) do
    %{
      contract_version: "v1",
      execution_governance_id: "execgov-agent-runtime-1",
      authority_ref: %{
        decision_id: "decision-1",
        policy_version: "policy-1",
        decision_hash: String.duplicate("a", 64)
      },
      sandbox: %{
        level: "strict",
        egress: "restricted",
        approvals: "manual",
        acceptable_attestation: ["manifest-descriptor"],
        allowed_tools: [],
        file_scope_ref: "workspace://tenant-1/project-1"
      },
      boundary: %{
        boundary_class: "governed_operation",
        trust_profile: "generic_operator",
        requested_attach_mode: "fresh_or_reuse",
        requested_ttl_ms: 30_000
      },
      topology: %{
        topology_intent_id: "topology-1",
        session_mode: "attached",
        coordination_mode: "single_target",
        topology_epoch: 1,
        routing_hints: %{}
      },
      workspace: %{
        workspace_profile: "binding_snapshot_workspace",
        logical_workspace_ref: "workspace://tenant-1/project-1",
        mutability: "read_write"
      },
      resources: %{
        resource_profile: "generic_operation_resource",
        wall_clock_budget_ms: 60_000
      },
      placement: %{
        execution_family: "process",
        placement_intent: "host_local",
        target_kind: "workspace"
      },
      operations: %{
        allowed_operations: ["runtime_tool_invocation"],
        effect_classes: ["external_effect"]
      },
      extensions: extensions
    }
  end
end
