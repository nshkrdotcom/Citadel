defmodule Citadel.ContractCore do
  @moduledoc """
  Packet-aligned ownership surface for `core/contract_core`.
  """

  @manifest %{
    package: :citadel_contract_core,
    layer: :core,
    status: :wave_1_skeleton,
    owns: [:neutral_identifiers, :host_local_refs, :canonical_json],
    internal_dependencies: [],
    external_dependencies: [:jcs]
  }

  @spec manifest() :: map()
  def manifest, do: @manifest
end
