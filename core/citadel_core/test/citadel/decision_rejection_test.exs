defmodule Citadel.DecisionRejectionTest do
  use ExUnit.Case, async: true

  alias Citadel.DecisionRejection
  alias Citadel.DecisionRejectionClassifier
  alias Citadel.PolicyPacks.PolicyPack

  test "governance and denial-audit posture wins mixed-cause publication classification" do
    rejection =
      DecisionRejectionClassifier.classify!(
        %{
          rejection_id: "rej-1",
          stage: :planning,
          reason_code: "policy_denied",
          summary: "policy denied execution",
          causes: [:runtime_state, :policy_denial],
          extensions: %{}
        },
        policy_pack()
      )

    assert %DecisionRejection{} = rejection
    assert rejection.retryability == :after_runtime_change
    assert rejection.publication_requirement == :review_projection
  end

  test "governance changes dominate retryability classification" do
    rejection =
      DecisionRejectionClassifier.classify!(
        %{
          rejection_id: "rej-2",
          stage: :service_admission,
          reason_code: "approval_missing",
          summary: "approval missing",
          causes: [:input, :governance],
          extensions: %{}
        },
        policy_pack()
      )

    assert rejection.retryability == :after_governance_change
    assert rejection.publication_requirement == :review_projection
  end

  defp policy_pack do
    PolicyPack.new!(%{
      pack_id: "default",
      policy_version: "policy-2026-04-09",
      policy_epoch: 7,
      priority: 0,
      selector: %{tenant_ids: [], scope_kinds: [], environments: [], default?: true, extensions: %{}},
      profiles: %{
        trust_profile: "baseline",
        approval_profile: "standard_approval",
        egress_profile: "restricted",
        workspace_profile: "default_workspace",
        resource_profile: "standard",
        boundary_class: "workspace_session",
        extensions: %{}
      },
      rejection_policy: %{
        denial_audit_reason_codes: ["policy_denied", "approval_missing"],
        derived_state_reason_codes: ["planning_failed"],
        runtime_change_reason_codes: ["scope_unavailable", "service_hidden", "boundary_stale"],
        governance_change_reason_codes: ["approval_missing"],
        extensions: %{}
      },
      extensions: %{}
    })
  end
end
