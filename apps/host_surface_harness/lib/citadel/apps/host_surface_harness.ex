defmodule Citadel.Apps.HostSurfaceHarness do
  @moduledoc """
  Packet-aligned ownership surface for `apps/host_surface_harness`.
  """

  @manifest %{
    package: :citadel_host_surface_harness,
    layer: :app,
    status: :wave_1_skeleton,
    owns: [:host_kernel_seam_proofs, :structured_ingress, :multi_session_probes],
    internal_dependencies: [
      :citadel_core,
      :citadel_runtime,
      :citadel_signal_bridge,
      :citadel_boundary_bridge,
      :citadel_trace_bridge
    ],
    external_dependencies: []
  }

  @spec proof_focus() :: [atom()]
  def proof_focus, do: [:structured_ingress, :multi_session_behavior, :host_kernel_boundary]

  @spec manifest() :: map()
  def manifest, do: @manifest
end
