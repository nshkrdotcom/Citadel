defmodule Citadel.MemoryBridge do
  @moduledoc """
  Packet-aligned ownership surface for `bridges/memory_bridge`.
  """

  @manifest %{
    package: :citadel_memory_bridge,
    layer: :bridge,
    status: :wave_1_skeleton,
    owns: [:advisory_memory_adapters, :memory_normalization, :correlation_translation],
    internal_dependencies: [:citadel_core, :citadel_runtime],
    external_dependencies: []
  }

  @spec advisory_modes() :: [atom()]
  def advisory_modes, do: [:retrieve, :append, :summarize]

  @spec manifest() :: map()
  def manifest, do: @manifest
end
