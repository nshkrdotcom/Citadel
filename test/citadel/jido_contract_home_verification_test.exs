defmodule Citadel.JidoContractHomeVerificationTest do
  use ExUnit.Case, async: true

  @repo_root Path.expand("../..", __DIR__)
  @retired_local_package Path.join(@repo_root, "core/jido_integration_contracts")
  @canonical_package Path.expand("../jido_integration/core/contracts", @repo_root)
  @canonical_slice Path.join(@canonical_package, "lib/jido/integration/v2")
  @required_contract_files [
    "authority_audit_envelope.ex",
    "brain_invocation.ex",
    "canonical_json.ex",
    "contracts.ex",
    "derived_state_attachment.ex",
    "evidence_ref.ex",
    "execution_governance_projection.ex",
    "execution_governance_projection/compiler.ex",
    "execution_governance_projection/verifier.ex",
    "governance_ref.ex",
    "review_projection.ex",
    "schema.ex",
    "subject_ref.ex",
    "submission_acceptance.ex",
    "submission_identity.ex",
    "submission_rejection.ex"
  ]

  test "Jido Integration owns the shared contracts app identity" do
    assert File.regular?(Path.join(@canonical_package, "mix.exs"))

    assert String.contains?(
             File.read!(Path.join(@canonical_package, "mix.exs")),
             "app: :jido_integration_contracts"
           )

    refute File.regular?(Path.join(@retired_local_package, "mix.exs"))

    assert [] = tracked_paths_starting_with("core/jido_integration_contracts")
  end

  test "canonical package contains every shared module Citadel imports" do
    assert File.dir?(@canonical_slice)

    for relative <- @required_contract_files do
      assert File.regular?(Path.join(@canonical_slice, relative))
    end
  end

  defp tracked_paths_starting_with(prefix) do
    {output, 0} = System.cmd("git", ["ls-files"], cd: @repo_root, stderr_to_stdout: true)

    output
    |> String.split("\n", trim: true)
    |> Enum.filter(&String.starts_with?(&1, prefix))
  end
end
