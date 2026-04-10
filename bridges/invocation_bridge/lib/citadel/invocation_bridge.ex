defmodule Citadel.InvocationBridge do
  @moduledoc """
  Packet-aligned ownership surface for `bridges/invocation_bridge`.
  """

  @manifest %{
    package: :citadel_invocation_bridge,
    layer: :bridge,
    status: :wave_1_skeleton,
    owns: [:invocation_handoff, :lower_seam_alignment, :request_projection],
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

  @spec manifest() :: map()
  def manifest, do: @manifest
end
