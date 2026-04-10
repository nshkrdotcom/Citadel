defmodule Citadel.BoundaryBridge do
  @moduledoc """
  Packet-aligned ownership surface for `bridges/boundary_bridge`.
  """

  @manifest %{
    package: :citadel_boundary_bridge,
    layer: :bridge,
    status: :wave_1_skeleton,
    owns: [:boundary_lifecycle_adapters, :lease_translation, :boundary_event_shaping],
    internal_dependencies: [:citadel_core, :citadel_runtime, :citadel_authority_contract],
    external_dependencies: []
  }

  @spec boundary_metadata_fields() :: [atom()]
  def boundary_metadata_fields, do: [:boundary_id, :boundary_class, :lease_ref, :authority_hash]

  @spec manifest() :: map()
  def manifest, do: @manifest
end
