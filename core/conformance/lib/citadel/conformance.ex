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

  @type contract_mode :: :path_local | :staged_artifact | :published_artifact

  @spec shared_contract_mode(keyword()) :: contract_mode()
  def shared_contract_mode(opts \\ []) do
    requested_contract_mode(opts)
  end

  @spec requested_contract_mode(keyword()) :: contract_mode()
  def requested_contract_mode(opts \\ []) do
    opts
    |> Keyword.get_lazy(:contract_mode, fn ->
      Application.get_env(:citadel_conformance, :contract_mode, :path_local)
    end)
    |> normalize_contract_mode()
  end

  @spec release_artifact_gate_requested?(keyword()) :: boolean()
  def release_artifact_gate_requested?(opts \\ []) do
    requested_contract_mode(opts) in [:staged_artifact, :published_artifact]
  end

  @spec published_artifact_gate_requested?(keyword()) :: boolean()
  def published_artifact_gate_requested?(opts \\ []) do
    requested_contract_mode(opts) == :published_artifact
  end

  defp normalize_contract_mode(mode)
       when mode in [:path_local, :staged_artifact, :published_artifact],
       do: mode

  defp normalize_contract_mode(mode) when mode in [:path, "path", "path_local"],
    do: :path_local

  defp normalize_contract_mode(mode) when mode in [:staged, "staged", "staged_artifact"],
    do: :staged_artifact

  defp normalize_contract_mode(mode) when mode in [:published, "published", "published_artifact"],
    do: :published_artifact

  defp normalize_contract_mode(_mode), do: :path_local
end
