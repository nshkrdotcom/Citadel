defmodule Citadel.AuthorityCanonicalizationAuditTest do
  use ExUnit.Case, async: true

  @decision_hash_owners [
    "core/citadel_governance/lib/citadel/decision_hash.ex",
    "core/authority_contract/lib/citadel/authority_contract/authority_packet/v2.ex"
  ]

  @hot_authority_callers [
    "bridges/host_ingress_bridge/lib/citadel/host_ingress/invocation_compiler.ex",
    "core/citadel_governance/lib/citadel/governance/substrate_ingress.ex"
  ]

  test "decision-hash owners use bounded canonical JSON before hashing" do
    offenders =
      Enum.reject(@decision_hash_owners, fn path ->
        source = File.read!(path)

        String.contains?(source, "CanonicalJson.encode_inline!(") and
          String.contains?(source, "max_authority_hash_inline_bytes")
      end)

    assert offenders == [],
           "decision-hash owners must route hash canonicalization through a bounded inline guard: #{inspect(offenders)}"
  end

  test "hot authority paths do not call direct JSON or JCS encoders" do
    forbidden_patterns = ["Jcs.encode", "Jason.encode!", "CanonicalJson.encode!("]

    offenders =
      (@decision_hash_owners ++ @hot_authority_callers)
      |> Enum.flat_map(fn path ->
        source = File.read!(path)

        forbidden_patterns
        |> Enum.filter(&String.contains?(source, &1))
        |> Enum.map(&{path, &1})
      end)

    assert offenders == [],
           "hot authority paths must not bypass the owned bounded canonicalization boundary: #{inspect(offenders)}"
  end

  test "hot ingress callers delegate authority hashes to the Citadel owner" do
    offenders =
      Enum.reject(@hot_authority_callers, fn path ->
        path
        |> File.read!()
        |> String.contains?("DecisionHash.put_authority_hash!(")
      end)

    assert offenders == [],
           "hot ingress callers must delegate decision hashes to Citadel.DecisionHash: #{inspect(offenders)}"
  end
end
