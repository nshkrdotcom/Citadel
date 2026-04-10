defmodule Citadel.ContractCore do
  @moduledoc """
  Packet-aligned ownership surface for `core/contract_core`.
  """

  @manifest %{
    package: :citadel_contract_core,
    layer: :core,
    status: :wave_2_seam_frozen,
    owns: [:neutral_identifiers, :host_local_refs, :canonical_json, :packet_attr_normalization],
    internal_dependencies: [],
    external_dependencies: [:jcs]
  }

  @spec manifest() :: map()
  def manifest, do: @manifest
end
