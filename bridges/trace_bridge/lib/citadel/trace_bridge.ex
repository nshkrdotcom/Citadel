defmodule Citadel.TraceBridge do
  @moduledoc """
  Packet-aligned ownership surface for `bridges/trace_bridge`.
  """

  @manifest %{
    package: :citadel_trace_bridge,
    layer: :bridge,
    status: :wave_1_skeleton,
    owns: [:trace_publication, :span_shaping, :observability_exports],
    internal_dependencies: [:citadel_runtime, :citadel_observability_contract],
    external_dependencies: []
  }

  @spec export_targets() :: [atom()]
  def export_targets, do: [:aitrace, :telemetry, :local_debug_sink]

  @spec manifest() :: map()
  def manifest, do: @manifest
end
