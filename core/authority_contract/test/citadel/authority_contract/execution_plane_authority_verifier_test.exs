defmodule Citadel.AuthorityContract.ExecutionPlaneAuthorityVerifierTest do
  use ExUnit.Case, async: true

  alias Citadel.AuthorityContract.ExecutionPlaneAuthorityVerifier
  alias ExecutionPlane.Admission.Rejection
  alias ExecutionPlane.Authority.Ref

  test "accepts a Citadel authority ref through the Execution Plane verifier behaviour" do
    authority_ref =
      Ref.new!(
        ref: "citadel://authority/decision-1",
        payload_hash: "sha256:" <> String.duplicate("a", 64),
        audience: "execution-plane-node",
        metadata: %{
          "decision_id" => "decision-1",
          "policy_version" => "policy-2026-04-24",
          "decision_hash" => String.duplicate("b", 64)
        }
      )

    assert {:ok, verified} =
             ExecutionPlaneAuthorityVerifier.verify(authority_ref,
               audience: "execution-plane-node",
               now_ms: 1
             )

    assert verified.verifier_id == "citadel-authority-decision-v1"
    assert verified.authority_ref == "citadel://authority/decision-1"
    assert verified.decision_id == "decision-1"
  end

  test "rejects missing and mismatched authority references" do
    assert {:error, %Rejection{reason: "invalid_authority_ref"}} =
             ExecutionPlaneAuthorityVerifier.verify(%Ref{}, [])

    assert {:error, %Rejection{reason: "authority_audience_mismatch"}} =
             ExecutionPlaneAuthorityVerifier.verify(
               Ref.new!(
                 ref: "citadel://authority/decision-1",
                 payload_hash: "sha256:" <> String.duplicate("a", 64),
                 audience: "wrong-node",
                 metadata: %{
                   "decision_id" => "decision-1",
                   "policy_version" => "policy-2026-04-24",
                   "decision_hash" => String.duplicate("b", 64)
                 }
               ),
               audience: "execution-plane-node"
             )
  end
end
