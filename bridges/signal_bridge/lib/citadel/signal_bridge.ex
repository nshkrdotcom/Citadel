defmodule Citadel.SignalBridge do
  @moduledoc """
  Packet-aligned ownership surface for `bridges/signal_bridge`.
  """

  @manifest %{
    package: :citadel_signal_bridge,
    layer: :bridge,
    status: :wave_1_skeleton,
    owns: [:signal_ingress_normalization, :channel_translation, :ingress_metadata],
    internal_dependencies: [:citadel_runtime, :citadel_observability_contract],
    external_dependencies: []
  }

  @spec normalized_signal_fields() :: [atom()]
  def normalized_signal_fields, do: [:signal_type, :channel_ref, :received_at, :metadata]

  @spec manifest() :: map()
  def manifest, do: @manifest
end
