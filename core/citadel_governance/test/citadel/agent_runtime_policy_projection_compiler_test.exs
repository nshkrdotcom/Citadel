defmodule Citadel.AgentRuntimePolicyProjectionCompilerTest do
  use ExUnit.Case, async: true

  alias Citadel.AgentRuntimePolicyProjection
  alias Citadel.AgentRuntimePolicyProjectionCompiler
  alias Citadel.PolicyPacks

  test "compiles allowed runtime posture into an agent runtime policy projection" do
    selection = generic_selection()

    assert {:ok, %AgentRuntimePolicyProjection{} = projection} =
             AgentRuntimePolicyProjectionCompiler.compile(selection, %{
               projection_ref: "agent-policy-projection://tenant-1/run-1",
               authority_ref: "authority://decision-1",
               tenant_ref: "tenant://tenant-1",
               requested_runtime_family: :process,
               requested_capability_class: :skill_invocation,
               skill_ref: "skill://document-review",
               interop_ref: "agent-interop://external-reviewer",
               credential_posture: :lease_only
             })

    assert projection.allowed_runtime_families == [:process, :http, :jsonrpc, :interop]
    assert projection.allowed_capability_classes == [:tool_call, :skill_invocation]
    assert projection.skill_allowlist_refs == ["skill://document-review"]
    assert projection.interop_allowlist_refs == ["agent-interop://external-reviewer"]
    assert projection.approval_requirements == [:skill_invocation]
    assert projection.credential_posture == :lease_only
  end

  test "fails closed without agent runtime policy" do
    selection =
      [PolicyPacks.coding_ops_standard_pack!()]
      |> PolicyPacks.select_profile!(%{
        tenant_id: "tenant-1",
        scope_kind: "project",
        environment: "prod"
      })
      |> Map.put(:agent_runtime_policy, nil)

    assert {:error, {:denied, :missing_agent_runtime_policy, _facts}} =
             AgentRuntimePolicyProjectionCompiler.compile(selection, compile_attrs())
  end

  test "denies unsupported runtime, raw endpoint, unknown skill, unknown interop, and budget broadening" do
    selection = generic_selection()

    assert {:error, {:denied, :forbidden_runtime_family, _facts}} =
             AgentRuntimePolicyProjectionCompiler.compile(
               selection,
               Map.put(compile_attrs(), :requested_runtime_family, :direct)
             )

    assert {:error, {:denied, :raw_endpoint_not_allowed, _facts}} =
             AgentRuntimePolicyProjectionCompiler.compile(
               selection,
               Map.put(compile_attrs(), :raw_endpoint_ref, "https://example.invalid")
             )

    assert {:error, {:denied, :unknown_skill_package, _facts}} =
             AgentRuntimePolicyProjectionCompiler.compile(
               selection,
               Map.put(compile_attrs(), :skill_ref, "skill://not-admitted")
             )

    assert {:error, {:denied, :unknown_interop_descriptor, _facts}} =
             AgentRuntimePolicyProjectionCompiler.compile(
               selection,
               Map.put(compile_attrs(), :interop_ref, "agent-interop://not-admitted")
             )

    assert {:error, {:denied, :budget_exceeds_policy, _facts}} =
             AgentRuntimePolicyProjectionCompiler.compile(
               selection,
               put_in(compile_attrs(), [:budget, :tool_calls], 21)
             )
  end

  test "rejects missing credential posture" do
    assert {:error, {:denied, :missing_credential_posture, _facts}} =
             AgentRuntimePolicyProjectionCompiler.compile(
               generic_selection(),
               Map.delete(compile_attrs(), :credential_posture)
             )
  end

  defp generic_selection do
    pack =
      PolicyPacks.generic_substrate_pack!(
        agent_runtime_skill_allowlist_refs: ["skill://document-review"],
        agent_runtime_interop_allowlist_refs: ["agent-interop://external-reviewer"],
        agent_runtime_approval_requirements: ["skill_invocation"],
        agent_runtime_budget: %{wall_clock_ms: 60_000, output_bytes: 1_000_000, tool_calls: 20}
      )

    PolicyPacks.select_profile!([pack], %{
      tenant_id: "tenant-1",
      scope_kind: "project",
      environment: "prod"
    })
  end

  defp compile_attrs do
    %{
      projection_ref: "agent-policy-projection://tenant-1/run-1",
      authority_ref: "authority://decision-1",
      tenant_ref: "tenant://tenant-1",
      requested_runtime_family: :process,
      requested_capability_class: :skill_invocation,
      skill_ref: "skill://document-review",
      interop_ref: "agent-interop://external-reviewer",
      credential_posture: :lease_only,
      budget: %{wall_clock_ms: 60_000, output_bytes: 1_000_000, tool_calls: 20}
    }
  end
end
