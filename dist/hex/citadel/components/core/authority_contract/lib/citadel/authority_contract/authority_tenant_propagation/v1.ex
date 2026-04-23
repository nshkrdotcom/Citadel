defmodule Citadel.AuthorityContract.AuthorityTenantPropagation.V1 do
  @moduledoc """
  Phase 6 aggregate evidence for authority and tenant propagation.

  The frozen `AuthorityDecision.v1` packet remains the authority primitive. This
  module owns the cross-repo evidence shape that proves Citadel authority facts
  were carried into Mezzanine authorization scope and Jido Integration lower
  facts without shortcutting the owner path.
  """

  alias Citadel.AuthorityContract.AuthorityDecision.V1, as: AuthorityDecisionV1

  @contract_id "AuthorityTenantPropagation.v1"
  @tenant_id "tenant-phase6-m8"
  @authority_decision_ref "authority-decision:phase6-m8"
  @budget_ref "budget://phase6/m8/local-no-spend"
  @lineage_ref "lineage://phase6/m8/exec-phase6-m8"
  @causation_ref "causation://phase6/m8/request-phase6-m8"
  @idempotency_ref "idempotency://phase6/m8/tenant-phase6-m8/request-phase6-m8"
  @authorization_scope_ref "authorization-scope://tenant-phase6-m8/exec-phase6-m8"
  @lower_facts_propagation_ref "lower-facts://tenant-phase6-m8/run-phase6-m8"

  @required_fields [
    :tenant_ref,
    :authority_decision_ref,
    :authorization_scope_ref,
    :budget_ref,
    :lineage_ref,
    :causation_ref,
    :idempotency_ref,
    :lower_facts_propagation_ref
  ]

  @forbidden [
    :harness_self_assertion_as_authority_evidence,
    :cross_tenant_lower_read,
    :missing_authority_or_scope_with_silent_pass,
    :direct_lower_shortcut_bypassing_authority
  ]

  @type contract :: %{
          id: String.t(),
          owner: :citadel_mezzanine_jido_integration,
          primary_repos: [:citadel | :mezzanine | :jido_integration, ...],
          phase6_milestone: :m8,
          required_fields: [atom()],
          forbidden: [atom()]
        }

  @type owner_evidence :: %{
          contract_id: String.t(),
          tenant_ref: String.t(),
          authority_decision_ref: String.t(),
          authorization_scope_ref: String.t(),
          budget_ref: String.t(),
          lineage_ref: String.t(),
          causation_ref: String.t(),
          idempotency_ref: String.t(),
          lower_facts_propagation_ref: String.t(),
          owner_path_refs: map(),
          forbidden_present?: false
        }

  @spec contract() :: contract()
  def contract do
    %{
      id: @contract_id,
      owner: :citadel_mezzanine_jido_integration,
      primary_repos: [:citadel, :mezzanine, :jido_integration],
      phase6_milestone: :m8,
      required_fields: @required_fields,
      forbidden: @forbidden
    }
  end

  @spec fixture() :: map()
  def fixture do
    %{
      authority_decision: authority_decision_fixture(),
      authorization_scope: %{
        tenant_id: @tenant_id,
        installation_id: "installation-phase6-m8",
        execution_id: "exec-phase6-m8",
        trace_id: "trace-phase6-m8",
        ref: @authorization_scope_ref
      },
      budget_ref: @budget_ref,
      lineage_ref: @lineage_ref,
      causation_ref: @causation_ref,
      idempotency_ref: @idempotency_ref,
      lower_facts: %{
        tenant_id: @tenant_id,
        installation_id: "installation-phase6-m8",
        run_id: "run-phase6-m8",
        propagation_ref: @lower_facts_propagation_ref,
        shortcut?: false
      },
      evidence_source: :owner_path
    }
  end

  @spec owner_evidence(map() | keyword()) :: {:ok, owner_evidence()} | {:error, term()}
  def owner_evidence(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = Map.new(attrs)

    with :ok <- reject_forbidden_source(attrs),
         {:ok, authority} <- authority_decision(attrs),
         tenant_id = authority.tenant_id,
         {:ok, budget_ref} <- required_ref(attrs, :budget_ref),
         {:ok, authorization_scope_ref} <- authorization_scope_ref(attrs, tenant_id),
         {:ok, lower_facts_ref} <- lower_facts_ref(attrs, tenant_id),
         {:ok, lineage_ref} <- required_ref(attrs, :lineage_ref),
         {:ok, causation_ref} <- required_ref(attrs, :causation_ref),
         {:ok, idempotency_ref} <- required_ref(attrs, :idempotency_ref) do
      {:ok,
       %{
         contract_id: @contract_id,
         tenant_ref: tenant_ref(tenant_id),
         authority_decision_ref: authority.decision_id,
         authorization_scope_ref: authorization_scope_ref,
         budget_ref: budget_ref,
         lineage_ref: lineage_ref,
         causation_ref: causation_ref,
         idempotency_ref: idempotency_ref,
         lower_facts_propagation_ref: lower_facts_ref,
         owner_path_refs: %{
           authority_decision_ref: authority.decision_id,
           authorization_scope_ref: authorization_scope_ref,
           budget_ref: budget_ref,
           lower_facts_propagation_ref: lower_facts_ref
         },
         forbidden_present?: false
       }}
    end
  end

  def owner_evidence(_attrs), do: {:error, :invalid_owner_evidence_attrs}

  defp reject_forbidden_source(%{evidence_source: source})
       when source in [:harness_self_assertion, "harness_self_assertion"] do
    {:error, {:forbidden_evidence, :harness_self_assertion_as_authority_evidence}}
  end

  defp reject_forbidden_source(_attrs), do: :ok

  defp authority_decision(%{authority_decision: nil}), do: {:error, :missing_authority_decision}

  defp authority_decision(%{authority_decision: %AuthorityDecisionV1{} = decision}),
    do: {:ok, decision}

  defp authority_decision(%{authority_decision: decision})
       when is_map(decision) or is_list(decision) do
    AuthorityDecisionV1.new(decision)
  end

  defp authority_decision(_attrs), do: {:error, :missing_authority_decision}

  defp authorization_scope_ref(attrs, tenant_id) do
    case Map.get(attrs, :authorization_scope) do
      scope when is_map(scope) ->
        with :ok <- ensure_tenant(scope, tenant_id, :authorization_scope_ref),
             {:ok, ref} <- required_nested_ref(scope, :ref, :authorization_scope_ref) do
          {:ok, ref}
        end

      _other ->
        {:error, :missing_authorization_scope_ref}
    end
  end

  defp lower_facts_ref(attrs, tenant_id) do
    case Map.get(attrs, :lower_facts) do
      %{shortcut?: true} ->
        {:error, {:forbidden_evidence, :direct_lower_shortcut_bypassing_authority}}

      lower_facts when is_map(lower_facts) ->
        with :ok <- ensure_lower_facts_tenant(lower_facts, tenant_id),
             {:ok, ref} <- required_nested_ref(lower_facts, :propagation_ref, :lower_facts) do
          {:ok, ref}
        end

      _other ->
        {:error, :missing_lower_facts_propagation_ref}
    end
  end

  defp ensure_tenant(scope, expected_tenant_id, field) do
    if Map.get(scope, :tenant_id) == expected_tenant_id do
      :ok
    else
      {:error, {:cross_tenant_ref, field}}
    end
  end

  defp ensure_lower_facts_tenant(lower_facts, expected_tenant_id) do
    case Map.get(lower_facts, :tenant_id) do
      ^expected_tenant_id -> :ok
      tenant_id -> {:error, {:lower_facts_tenant_mismatch, tenant_id}}
    end
  end

  defp required_ref(attrs, :budget_ref) do
    case Map.get(attrs, :budget_ref) do
      ref when is_binary(ref) and ref != "" -> {:ok, ref}
      _other -> {:error, :missing_budget_ref}
    end
  end

  defp required_ref(attrs, field) do
    case Map.get(attrs, field) do
      ref when is_binary(ref) and ref != "" -> {:ok, ref}
      _other -> {:error, {:missing_required_ref, field}}
    end
  end

  defp required_nested_ref(attrs, key, field) do
    case Map.get(attrs, key) do
      ref when is_binary(ref) and ref != "" -> {:ok, ref}
      _other -> {:error, {:missing_required_ref, field}}
    end
  end

  defp tenant_ref(tenant_id), do: "tenant:" <> tenant_id

  defp authority_decision_fixture do
    AuthorityDecisionV1.new!(%{
      contract_version: "v1",
      decision_id: @authority_decision_ref,
      tenant_id: @tenant_id,
      request_id: "request-phase6-m8",
      policy_version: "policy-phase6-m8",
      boundary_class: "governed_substrate",
      trust_profile: "single-tenant",
      approval_profile: "operator-reviewed",
      egress_profile: "no-egress",
      workspace_profile: "tenant-workspace",
      resource_profile: "lower-execution",
      decision_hash: String.duplicate("8", 64),
      extensions: %{
        "citadel" => %{
          "budget_policy" => %{
            "budget_ref" => @budget_ref,
            "max_cost_units" => 0,
            "spend_allowed" => false
          },
          "no_bypass_scope" => "authority+tenant+budget+lower_facts"
        }
      }
    })
  end
end
