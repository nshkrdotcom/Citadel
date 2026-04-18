defmodule Citadel.Apps.OperatorAssist do
  @moduledoc """
  Packet-aligned ownership surface for `apps/operator_assist`.
  """

  @manifest %{
    package: :citadel_operator_assist,
    layer: :app,
    status: :wave_1_skeleton,
    owns: [:operator_surface, :approval_workflows, :proof_app_composition],
    internal_dependencies: [
      :citadel_governance,
      :citadel_kernel,
      :citadel_invocation_bridge,
      :citadel_query_bridge,
      :citadel_signal_bridge,
      :citadel_boundary_bridge,
      :citadel_projection_bridge,
      :citadel_trace_bridge
    ],
    external_dependencies: []
  }

  @spec proof_focus() :: [atom()]
  def proof_focus, do: [:operator_intake, :approvals, :run_supervision]

  @spec manifest() :: map()
  def manifest, do: @manifest
end
