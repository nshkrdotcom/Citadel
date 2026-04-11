defmodule Citadel.DecisionHash do
  @moduledoc """
  Canonical `decision_hash` implementation for `AuthorityDecision.v1`.

  The hash is computed from the projected shared packet with `decision_hash`
  removed, normalized through `Citadel.ContractCore.CanonicalJson`, encoded with
  `Jcs.encode/1`, and digested with SHA-256.
  """

  alias Citadel.AuthorityContract.AuthorityDecision.V1
  alias Citadel.ContractCore.AttrMap
  alias Citadel.ContractCore.CanonicalJson

  @pending_hash String.duplicate("0", 64)

  @spec authority_hash!(V1.t() | map() | keyword()) :: String.t()
  def authority_hash!(%V1{} = packet) do
    packet
    |> V1.hash_payload()
    |> canonical_payload!()
    |> sha256_lower_hex()
  end

  def authority_hash!(attrs) do
    attrs
    |> build_pending_packet!()
    |> authority_hash!()
  end

  @spec canonical_payload!(V1.t() | map()) :: String.t()
  def canonical_payload!(%V1{} = packet) do
    packet
    |> V1.hash_payload()
    |> canonical_payload!()
  end

  def canonical_payload!(payload) when is_map(payload) do
    CanonicalJson.encode!(payload)
  end

  @spec put_authority_hash!(V1.t() | map() | keyword()) :: V1.t()
  def put_authority_hash!(%V1{} = packet) do
    packet
    |> V1.dump()
    |> Map.put(:decision_hash, authority_hash!(packet))
    |> V1.new!()
  end

  def put_authority_hash!(attrs) do
    packet = build_pending_packet!(attrs)

    packet
    |> V1.dump()
    |> Map.put(:decision_hash, authority_hash!(packet))
    |> V1.new!()
  end

  @spec authority_hash_valid?(V1.t()) :: boolean()
  def authority_hash_valid?(%V1{} = packet) do
    packet.decision_hash == authority_hash!(packet)
  end

  defp build_pending_packet!(attrs) do
    attrs
    |> AttrMap.normalize!("AuthorityDecision hash input")
    |> Map.put("decision_hash", @pending_hash)
    |> V1.new!()
  end

  defp sha256_lower_hex(canonical_json) when is_binary(canonical_json) do
    :sha256
    |> :crypto.hash(canonical_json)
    |> Base.encode16(case: :lower)
  end
end
