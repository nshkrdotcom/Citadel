defmodule Citadel.PolicySurfaceTest do
  use ExUnit.Case, async: true

  alias Citadel.AuthorityDecision
  alias Citadel.PolicyPacks.Profiles

  test "authority decisions expose a stable policy-stage surface" do
    authority =
      AuthorityDecision.new!(%{
        contract_version: "v1",
        decision_id: "decision-1",
        tenant_id: "tenant-1",
        request_id: "request-1",
        policy_version: "policy-2026-04-11",
        boundary_class: "workspace_session",
        trust_profile: "trusted_operator",
        approval_profile: "approval_required",
        egress_profile: "restricted",
        workspace_profile: "project_workspace",
        resource_profile: "standard",
        decision_hash: String.duplicate("a", 64),
        extensions: %{}
      })

    assert AuthorityDecision.policy_surface(authority) == %{
             decision_id: "decision-1",
             policy_version: "policy-2026-04-11",
             boundary_class: "workspace_session",
             trust_profile: "trusted_operator",
             approval_profile: "approval_required",
             egress_profile: "restricted",
             workspace_profile: "project_workspace",
             resource_profile: "standard"
           }
  end

  test "policy pack profiles expose the same stable upper surface" do
    profiles =
      Profiles.new!(%{
        trust_profile: "baseline",
        approval_profile: "standard_approval",
        egress_profile: "restricted",
        workspace_profile: "default_workspace",
        resource_profile: "standard",
        boundary_class: "workspace_session",
        extensions: %{}
      })

    assert Profiles.policy_surface(profiles) == %{
             trust_profile: "baseline",
             approval_profile: "standard_approval",
             egress_profile: "restricted",
             workspace_profile: "default_workspace",
             resource_profile: "standard",
             boundary_class: "workspace_session"
           }
  end
end
