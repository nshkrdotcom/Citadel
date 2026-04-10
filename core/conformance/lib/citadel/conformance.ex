defmodule Citadel.Conformance do
  @moduledoc """
  Packet-aligned ownership surface for `core/conformance`.
  """

  @manifest %{
    package: :citadel_conformance,
    layer: :core,
    status: :wave_1_skeleton,
    owns: [:conformance_fixtures, :cross_package_verification, :composition_tests],
    internal_dependencies: [
      :citadel_contract_core,
      :citadel_authority_contract,
      :citadel_observability_contract,
      :citadel_policy_packs,
      :citadel_core,
      :citadel_runtime,
      :citadel_invocation_bridge,
      :citadel_query_bridge,
      :citadel_signal_bridge,
      :citadel_boundary_bridge,
      :citadel_projection_bridge,
      :citadel_trace_bridge,
      :citadel_memory_bridge,
      :citadel_coding_assist,
      :citadel_operator_assist,
      :citadel_host_surface_harness
    ],
    external_dependencies: [:jido_integration_v2_contracts]
  }

  @spec manifest() :: map()
  def manifest, do: @manifest
end
