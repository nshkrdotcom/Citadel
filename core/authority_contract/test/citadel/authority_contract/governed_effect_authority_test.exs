defmodule Citadel.AuthorityContract.GovernedEffectAuthorityTest do
  use ExUnit.Case, async: true

  alias Citadel.AuthorityContract.AuthorityDecision.V1, as: AuthorityDecisionV1
  alias Citadel.AuthorityContract.GovernedEffectAuthority
  alias Citadel.AuthorityContract.GovernedEffectAuthorityRequest
  alias Citadel.AuthorityContract.GovernedEffectRiskClassifier

  test "valid diagnostic request returns effect-aware AuthorityDecision.v1" do
    assert {:ok, decision} = GovernedEffectAuthority.authorize(diagnostic_request())

    assert %AuthorityDecisionV1{} = decision
    assert decision.boundary_class == "diagnostic"
    assert decision.approval_profile == "auto"
    assert AuthorityDecisionV1.governed_effect_decision(decision) == "allow"
    assert AuthorityDecisionV1.effect_type_allowed(decision) == allowed_diagnostic_effect_types()
    assert AuthorityDecisionV1.effect_risk_class(decision) == "low"
    refute AuthorityDecisionV1.compensation_required?(decision)
    refute AuthorityDecisionV1.review_required_for_effect?(decision)
  end

  test "forbidden effect type returns explicit denied AuthorityDecision.v1" do
    request = %{diagnostic_request() | effect_type: "delete"}

    assert {:ok, decision} = GovernedEffectAuthority.authorize(request)

    assert AuthorityDecisionV1.governed_effect_decision(decision) == "deny"
    assert AuthorityDecisionV1.effect_risk_class(decision) == "critical"

    assert AuthorityDecisionV1.governed_effect_denial_reason(decision) ==
             "effect_type_not_allowed"

    assert AuthorityDecisionV1.effect_type_allowed(decision) == allowed_diagnostic_effect_types()
  end

  test "review-required diagnostic request marks review before dispatch" do
    request = %{
      diagnostic_request()
      | effect_type: "diagnostic.probe",
        operation_type: "diagnostic.probe",
        side_effect_class: "external_call",
        target_refs: ["http://localhost:4000/health"]
    }

    assert {:ok, decision} = GovernedEffectAuthority.authorize(request)

    assert AuthorityDecisionV1.governed_effect_decision(decision) == "allow"
    assert AuthorityDecisionV1.effect_risk_class(decision) == "medium"
    assert AuthorityDecisionV1.review_required_for_effect?(decision)
  end

  test "request rejects missing tenant_ref" do
    assert_raise ArgumentError, fn ->
      diagnostic_request() |> Map.put(:tenant_ref, "") |> GovernedEffectAuthorityRequest.new!()
    end
  end

  test "risk classifier is bounded and feeds authority decisions" do
    assert %{risk_class: :low, review_required?: false} =
             GovernedEffectRiskClassifier.classify!(diagnostic_request())

    unknown = %{diagnostic_request() | effect_type: "unknown.effect"}

    assert %{risk_class: :high, review_required?: true} =
             GovernedEffectRiskClassifier.classify!(unknown)

    assert {:ok, decision} = GovernedEffectAuthority.authorize(unknown)
    assert AuthorityDecisionV1.governed_effect_decision(decision) == "deny"
    assert AuthorityDecisionV1.effect_risk_class(decision) == "high"
  end

  defp diagnostic_request do
    GovernedEffectAuthorityRequest.new!(%{
      request_ref: "authority-request://tenant-a/diagnostic/001",
      tenant_ref: "tenant-a",
      actor_ref: "actor://user/operator-a",
      installation_ref: "installation://tenant-a/default",
      effect_ref: "effect://tenant-a/diagnostic/001",
      effect_type: "diagnostic.echo",
      operation_type: "diagnostic.echo",
      resource_class: "diagnostic_lane",
      side_effect_class: "none",
      target_refs: ["diagnostic://echo"],
      budget_refs: ["budget://tenant-a/diagnostic"],
      residency_refs: ["residency://local"]
    })
  end

  defp allowed_diagnostic_effect_types do
    ["diagnostic", "diagnostic.echo", "diagnostic.probe"]
  end
end
