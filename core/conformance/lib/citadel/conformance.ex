defmodule Citadel.Conformance do
  @moduledoc """
  Black-box conformance ownership surface for `core/conformance`.
  """

  @manifest %{
    package: :citadel_conformance,
    layer: :core,
    status: :wave_7_black_box_conformance,
    owns: [:conformance_fixtures, :cross_package_verification, :composition_tests],
    internal_dependencies: [
      :citadel_contract_core,
      :citadel_authority_contract,
      :citadel_observability_contract,
      :citadel_policy_packs,
      :citadel_governance,
      :citadel_kernel,
      :citadel_invocation_bridge,
      :citadel_query_bridge,
      :citadel_signal_bridge,
      :citadel_boundary_bridge,
      :citadel_projection_bridge,
      :citadel_trace_bridge,
      :citadel_coding_assist,
      :citadel_operator_assist,
      :citadel_host_surface_harness
    ],
    external_dependencies: [:jido_integration_contracts]
  }

  @spec manifest() :: map()
  def manifest, do: @manifest

  @spec shared_contract_mode() :: :path_local | :staged_artifact | :published_artifact
  def shared_contract_mode do
    requested_contract_mode()
  end

  @spec requested_contract_mode() :: :path_local | :staged_artifact | :published_artifact
  def requested_contract_mode do
    case System.get_env("CITADEL_CONFORMANCE_CONTRACT_MODE") do
      "published" -> :published_artifact
      "staged" -> :staged_artifact
      _ -> :path_local
    end
  end

  @spec release_artifact_gate_requested?() :: boolean()
  def release_artifact_gate_requested? do
    requested_contract_mode() in [:staged_artifact, :published_artifact]
  end

  @spec published_artifact_gate_requested?() :: boolean()
  def published_artifact_gate_requested? do
    requested_contract_mode() == :published_artifact
  end
end
