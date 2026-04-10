defmodule Citadel.Runtime do
  @moduledoc """
  Packet-aligned ownership surface for `core/citadel_runtime`.
  """

  @manifest %{
    package: :citadel_runtime,
    layer: :core,
    status: :wave_1_skeleton,
    owns: [:session_runtime, :signal_ingress, :outbox_replay, :runtime_coordination],
    internal_dependencies: [
      :citadel_core,
      :citadel_authority_contract,
      :citadel_observability_contract
    ],
    external_dependencies: []
  }

  @spec manifest() :: map()
  def manifest, do: @manifest
end
