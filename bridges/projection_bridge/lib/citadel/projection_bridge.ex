defmodule Citadel.ProjectionBridge do
  @moduledoc """
  Packet-aligned ownership surface for `bridges/projection_bridge`.
  """

  @manifest %{
    package: :citadel_projection_bridge,
    layer: :bridge,
    status: :wave_1_skeleton,
    owns: [:review_publication, :derived_state_projection, :packet_translation],
    internal_dependencies: [
      :citadel_core,
      :citadel_runtime,
      :citadel_authority_contract,
      :citadel_observability_contract
    ],
    external_dependencies: [:jido_integration_v2_contracts]
  }

  @spec shared_contract_strategy() :: :explicit_placeholder
  def shared_contract_strategy, do: :explicit_placeholder

  @spec publication_targets() :: [atom()]
  def publication_targets, do: [:review_bus, :derived_state_store, :boundary_projection]

  @spec manifest() :: map()
  def manifest, do: @manifest
end
