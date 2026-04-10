defmodule Citadel.Core do
  @moduledoc """
  Packet-aligned ownership surface for `core/citadel_core`.
  """

  @manifest %{
    package: :citadel_core,
    layer: :core,
    status: :wave_1_skeleton,
    owns: [:pure_values, :compilers, :reducers, :projectors],
    internal_dependencies: [
      :citadel_contract_core,
      :citadel_authority_contract,
      :citadel_observability_contract,
      :citadel_policy_packs
    ],
    external_dependencies: [:jido_integration_v2_contracts]
  }

  @spec shared_contract_strategy() :: :explicit_placeholder
  def shared_contract_strategy, do: :explicit_placeholder

  @spec manifest() :: map()
  def manifest, do: @manifest
end
