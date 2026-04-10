defmodule Citadel.QueryBridge do
  @moduledoc """
  Packet-aligned ownership surface for `bridges/query_bridge`.
  """

  @manifest %{
    package: :citadel_query_bridge,
    layer: :bridge,
    status: :wave_1_skeleton,
    owns: [:rehydration_adapters, :query_normalization, :external_snapshot_lookup],
    internal_dependencies: [:citadel_core, :citadel_runtime],
    external_dependencies: []
  }

  @spec rehydration_sources() :: [atom()]
  def rehydration_sources, do: [:session_snapshot, :boundary_projection, :external_query_result]

  @spec manifest() :: map()
  def manifest, do: @manifest
end
