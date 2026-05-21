defmodule Citadel.PolicyPacks.AgentRuntimePolicyTest do
  use ExUnit.Case, async: true

  alias Citadel.PolicyPacks
  alias Citadel.PolicyPacks.AgentRuntimePolicy

  test "generic substrate pack carries provider-neutral agent runtime posture" do
    pack = PolicyPacks.generic_substrate_pack!()

    assert %AgentRuntimePolicy{} = pack.agent_runtime_policy

    assert pack.agent_runtime_policy.allowed_runtime_families == [
             "process",
             "http",
             "jsonrpc",
             "interop"
           ]

    assert pack.agent_runtime_policy.allowed_capability_classes == [
             "tool_call",
             "skill_invocation"
           ]

    assert pack.agent_runtime_policy.credential_posture == "lease_only"
    assert pack.agent_runtime_policy.network_posture == "restricted"
    assert pack.agent_runtime_policy.budget.wall_clock_ms == 300_000

    dumped = inspect(PolicyPacks.PolicyPack.dump(pack))

    refute String.contains?(dumped, "codex")
    refute String.contains?(dumped, "github")
    refute String.contains?(dumped, "linear")
  end

  test "agent runtime policy rejects broad or missing posture" do
    assert_raise ArgumentError, fn ->
      AgentRuntimePolicy.new!(%{
        allowed_runtime_families: ["process", "shell_anywhere"],
        allowed_capability_classes: ["tool_call"],
        denied_capability_classes: [],
        skill_allowlist_refs: [],
        interop_allowlist_refs: [],
        approval_requirements: [],
        network_posture: "restricted",
        artifact_posture: "claim_checked",
        credential_posture: "lease_only",
        budget: %{wall_clock_ms: 1_000, output_bytes: 1_000, tool_calls: 1},
        redaction_posture: "product_safe",
        revision: 1,
        extensions: %{}
      })
    end

    assert_raise ArgumentError, fn ->
      AgentRuntimePolicy.new!(%{
        allowed_runtime_families: ["process"],
        allowed_capability_classes: ["tool_call"],
        denied_capability_classes: [],
        skill_allowlist_refs: [],
        interop_allowlist_refs: [],
        approval_requirements: [],
        network_posture: "open",
        artifact_posture: "claim_checked",
        credential_posture: "lease_only",
        budget: %{wall_clock_ms: 1_000, output_bytes: 1_000, tool_calls: 1},
        redaction_posture: "product_safe",
        revision: 1,
        extensions: %{}
      })
    end
  end
end
