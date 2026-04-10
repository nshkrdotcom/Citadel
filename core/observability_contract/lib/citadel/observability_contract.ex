defmodule Citadel.ObservabilityContract do
  @moduledoc """
  Packet-aligned ownership surface for `core/observability_contract`.
  """

  @manifest %{
    package: :citadel_observability_contract,
    layer: :core,
    status: :wave_1_skeleton,
    owns: [:trace_vocabulary, :telemetry_names, :metadata_conventions],
    internal_dependencies: [:citadel_contract_core],
    external_dependencies: []
  }

  @spec telemetry_prefix() :: [atom()]
  def telemetry_prefix, do: [:citadel]

  @spec manifest() :: map()
  def manifest, do: @manifest
end
