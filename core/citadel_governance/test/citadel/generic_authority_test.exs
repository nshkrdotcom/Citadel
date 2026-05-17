defmodule Citadel.GenericAuthorityTest do
  use ExUnit.Case, async: true

  alias Citadel.Authority

  test "decides capability from actor tenant installation operation class and capability first" do
    assert {:ok, decision} =
             Authority.decide_capability(
               "actor://operator/1",
               "tenant://acme",
               "installation://acme/extravaganza",
               :source_read,
               "issue_tracker",
               allowed_operation_classes: [:source_read],
               allowed_capabilities: ["issue_tracker"]
             )

    assert decision.result == :allowed
    assert decision.stage == :capability
    assert decision.actor_ref == "actor://operator/1"
    assert decision.tenant_ref == "tenant://acme"
    assert decision.installation_ref == "installation://acme/extravaganza"
    assert decision.operation_class == :source_read
    assert decision.capability == "issue_tracker"
    assert decision.manifest_ref == nil
    assert decision.binding_ref == nil
  end

  test "pure capability check can require review before manifest constraints exist" do
    assert {:ok, decision} =
             Authority.decide_capability(
               "actor://operator/1",
               "tenant://acme",
               "installation://acme/extravaganza",
               :resource_effect,
               "cleanup_branch",
               allowed_operation_classes: [:resource_effect],
               allowed_capabilities: ["cleanup_branch"],
               review_required_operation_classes: [:resource_effect]
             )

    assert decision.result == :review_required
    assert decision.stage == :capability
    assert decision.reason_code == "review_required_for_operation_class"
  end

  test "resolved-plan authorization uses operation class and manifest refs as data" do
    assert {:ok, decision} =
             Authority.authorize_resolved_plan(
               resolved_plan_request(:runtime_tool_invocation),
               allowed_operation_classes: [:runtime_tool_invocation],
               allowed_capabilities: ["issue_graphql_tool"],
               allowed_manifest_refs: ["manifest://linear/graphql"],
               allowed_binding_refs: ["binding://tenant/tool/issue-graphql"],
               allowed_credential_scope_refs: ["credential-scope://tenant/linear/graphql"],
               allowed_side_effect_classes: ["read"],
               allowed_required_scopes: ["issues:read"]
             )

    assert decision.result == :allowed
    assert decision.stage == :resolved_plan
    assert decision.operation_class == :runtime_tool_invocation
    assert decision.manifest_ref == "manifest://linear/graphql"
    assert decision.binding_ref == "binding://tenant/tool/issue-graphql"
    assert decision.credential_scope_ref == "credential-scope://tenant/linear/graphql"
  end

  test "Linear GraphQL manifests are tool invocations, not source writes" do
    assert {:ok, decision} =
             Authority.authorize_resolved_plan(
               resolved_plan_request(:source_write),
               allowed_operation_classes: [:runtime_tool_invocation],
               allowed_capabilities: ["issue_graphql_tool"],
               allowed_manifest_refs: ["manifest://linear/graphql"],
               allowed_binding_refs: ["binding://tenant/tool/issue-graphql"],
               allowed_credential_scope_refs: ["credential-scope://tenant/linear/graphql"],
               allowed_side_effect_classes: ["read"],
               allowed_required_scopes: ["issues:read"]
             )

    assert decision.result == :rejected
    assert decision.stage == :capability
    assert decision.reason_code == "operation_class_not_allowed"
    assert decision.operation_class == :source_write
  end

  test "resolved-plan constraints fail closed on scope expansion and missing confirmation policy" do
    assert {:ok, scope_decision} =
             Authority.authorize_resolved_plan(
               resolved_plan_request(:runtime_tool_invocation)
               |> Map.put(:required_scopes, ["issues:read", "issues:write"]),
               allowed_operation_classes: [:runtime_tool_invocation],
               allowed_capabilities: ["issue_graphql_tool"],
               allowed_manifest_refs: ["manifest://linear/graphql"],
               allowed_binding_refs: ["binding://tenant/tool/issue-graphql"],
               allowed_credential_scope_refs: ["credential-scope://tenant/linear/graphql"],
               allowed_side_effect_classes: ["read"],
               allowed_required_scopes: ["issues:read"]
             )

    assert scope_decision.result == :rejected
    assert scope_decision.reason_code == "required_scope_not_allowed"
    assert scope_decision.recovery_owner == :platform_citadel_operator

    assert {:ok, confirmation_decision} =
             Authority.authorize_resolved_plan(
               resolved_plan_request(:resource_effect)
               |> Map.merge(%{
                 capability: "cleanup_branch",
                 side_effect_class: "write",
                 required_scopes: ["repo:write"],
                 confirmation_policy_ref: nil
               }),
               allowed_operation_classes: [:resource_effect],
               allowed_capabilities: ["cleanup_branch"],
               allowed_manifest_refs: ["manifest://linear/graphql"],
               allowed_binding_refs: ["binding://tenant/tool/issue-graphql"],
               allowed_credential_scope_refs: ["credential-scope://tenant/linear/graphql"],
               allowed_side_effect_classes: ["write"],
               allowed_required_scopes: ["repo:write"],
               confirmation_required_operation_classes: [:resource_effect]
             )

    assert confirmation_decision.result == :rejected
    assert confirmation_decision.reason_code == "missing_confirmation_policy"
    assert confirmation_decision.retryable? == false
  end

  defp resolved_plan_request(operation_class) do
    %{
      actor_ref: "actor://operator/1",
      tenant_ref: "tenant://acme",
      installation_ref: "installation://acme/extravaganza",
      operation_class: operation_class,
      capability: "issue_graphql_tool",
      manifest_ref: "manifest://linear/graphql",
      operation_ref: "operation://linear/graphql/query",
      binding_ref: "binding://tenant/tool/issue-graphql",
      credential_scope_ref: "credential-scope://tenant/linear/graphql",
      side_effect_class: "read",
      required_scopes: ["issues:read"],
      confirmation_policy_ref: "confirmation-policy://tenant/tool/read",
      trace_ref: "trace://authority/1",
      metadata: %{"provider_family" => "linear"}
    }
  end
end
