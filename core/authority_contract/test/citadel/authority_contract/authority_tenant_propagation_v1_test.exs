defmodule Citadel.AuthorityContract.AuthorityTenantPropagation.V1Test do
  use ExUnit.Case, async: true

  alias Citadel.AuthorityContract
  alias Citadel.AuthorityContract.AuthorityDecision.V1, as: AuthorityDecisionV1
  alias Citadel.AuthorityContract.AuthorityTenantPropagation.V1

  test "exposes the Phase 6 authority/tenant propagation contract through the facade" do
    contract = V1.contract()

    assert AuthorityContract.authority_tenant_propagation_module() == V1
    assert contract.id == "AuthorityTenantPropagation.v1"
    assert contract.owner == :citadel_mezzanine_jido_integration
    assert contract.primary_repos == [:citadel, :mezzanine, :jido_integration]

    assert contract.required_fields == [
             :tenant_ref,
             :authority_decision_ref,
             :authorization_scope_ref,
             :budget_ref,
             :lineage_ref,
             :causation_ref,
             :idempotency_ref,
             :lower_facts_propagation_ref
           ]

    assert :direct_lower_shortcut_bypassing_authority in contract.forbidden
  end

  test "builds owner evidence from AuthorityDecision.v1 and populated downstream refs" do
    fixture = V1.fixture()

    assert {:ok, evidence} = V1.owner_evidence(fixture)

    assert evidence.contract_id == "AuthorityTenantPropagation.v1"
    assert evidence.tenant_ref == "tenant:tenant-phase6-m8"
    assert evidence.authority_decision_ref == "authority-decision:phase6-m8"

    assert evidence.authorization_scope_ref ==
             "authorization-scope://tenant-phase6-m8/exec-phase6-m8"

    assert evidence.budget_ref == "budget://phase6/m8/local-no-spend"
    assert evidence.lower_facts_propagation_ref == "lower-facts://tenant-phase6-m8/run-phase6-m8"
    assert evidence.owner_path_refs.authority_decision_ref == evidence.authority_decision_ref
    assert evidence.owner_path_refs.budget_ref == evidence.budget_ref
    refute evidence.forbidden_present?
  end

  test "fails closed for missing authority, cross-tenant refs, missing budget, and lower facts mismatch" do
    fixture = V1.fixture()

    assert {:error, :missing_authority_decision} =
             fixture
             |> Map.put(:authority_decision, nil)
             |> V1.owner_evidence()

    assert {:error, {:cross_tenant_ref, :authorization_scope_ref}} =
             fixture
             |> put_in([:authorization_scope, :tenant_id], "tenant-other")
             |> V1.owner_evidence()

    assert {:error, :missing_budget_ref} =
             fixture
             |> Map.put(:budget_ref, nil)
             |> V1.owner_evidence()

    assert {:error, {:lower_facts_tenant_mismatch, "tenant-other"}} =
             fixture
             |> put_in([:lower_facts, :tenant_id], "tenant-other")
             |> V1.owner_evidence()
  end

  test "rejects harness assertions and direct lower shortcuts as authority evidence" do
    fixture = V1.fixture()

    assert {:error, {:forbidden_evidence, :harness_self_assertion_as_authority_evidence}} =
             fixture
             |> Map.put(:evidence_source, :harness_self_assertion)
             |> V1.owner_evidence()

    assert {:error, {:forbidden_evidence, :direct_lower_shortcut_bypassing_authority}} =
             fixture
             |> Map.put(:lower_facts, %{tenant_id: "tenant-phase6-m8", shortcut?: true})
             |> V1.owner_evidence()
  end

  test "fixture carries a real AuthorityDecision.v1 value" do
    assert %AuthorityDecisionV1{tenant_id: "tenant-phase6-m8"} = V1.fixture().authority_decision
  end
end
