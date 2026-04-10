defmodule Citadel.InvocationRequestTest do
  use ExUnit.Case, async: true

  alias Citadel.AuthorityContract.AuthorityDecision.V1
  alias Citadel.BoundaryIntent
  alias Citadel.ContractCore.CanonicalJson
  alias Citadel.DecisionHash
  alias Citadel.InvocationRequest
  alias Citadel.TopologyIntent

  @authority_fixture_dir Path.expand(
                           "../../../authority_contract/test/fixtures/authority_decision_v1",
                           __DIR__
                         )
  @invocation_fixture_dir Path.expand("../fixtures/invocation_request", __DIR__)

  test "recomputes the frozen authority decision hash through contract_core" do
    fixture = read_authority_fixture!("with_citadel_extensions.json")
    packet = V1.new!(fixture)

    assert DecisionHash.authority_hash!(packet) == fixture["decision_hash"]
    assert DecisionHash.authority_hash_valid?(packet)

    rebuilt =
      fixture
      |> Map.delete("decision_hash")
      |> DecisionHash.put_authority_hash!()

    assert CanonicalJson.normalize!(V1.dump(rebuilt)) == fixture
  end

  test "rejects unsupported extension values during authority hash normalization" do
    attrs =
      read_authority_fixture!("minimal.json")
      |> Map.delete("decision_hash")
      |> put_in(["extensions", "citadel"], %{"bad" => {:tuple, 1}})

    assert_raise ArgumentError, ~r/unsupported non-JSON value/, fn ->
      DecisionHash.put_authority_hash!(attrs)
    end
  end

  test "freezes the invocation request seam and structured-ingress fixture" do
    fixture = read_invocation_fixture!("structured_request.json")
    request = InvocationRequest.new!(fixture)

    assert BoundaryIntent.schema() == [
             boundary_class: :string,
             trust_profile: :string,
             workspace_profile: :string,
             resource_profile: :string,
             requested_attach_mode: :string,
             requested_ttl_ms: :non_neg_integer,
             extensions: {:map, :json}
           ]

    assert TopologyIntent.schema() == [
             topology_intent_id: :string,
             session_mode: :string,
             routing_hints: {:map, :json},
             coordination_mode: :string,
             topology_epoch: :non_neg_integer,
             extensions: {:map, :json}
           ]

    assert InvocationRequest.schema_version() == 1
    assert InvocationRequest.structured_ingress_posture() == :structured_only
    assert InvocationRequest.authority_packet_module() == V1
    assert request.authority_packet.__struct__ == V1
    assert CanonicalJson.normalize!(InvocationRequest.dump(request)) == fixture
  end

  test "rejects raw ingress payload keys in provenance" do
    fixture =
      read_invocation_fixture!("structured_request.json")
      |> put_in(["extensions", "citadel", "ingress_provenance", "raw_text"], "open the repo")

    assert_raise ArgumentError, ~r/refs or hashes, not raw payload keys/, fn ->
      InvocationRequest.new!(fixture)
    end
  end

  defp read_authority_fixture!(name) do
    @authority_fixture_dir
    |> Path.join(name)
    |> File.read!()
    |> Jason.decode!()
  end

  defp read_invocation_fixture!(name) do
    @invocation_fixture_dir
    |> Path.join(name)
    |> File.read!()
    |> Jason.decode!()
  end
end
