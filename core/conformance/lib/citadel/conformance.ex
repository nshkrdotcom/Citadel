defmodule Citadel.Conformance do
  @moduledoc """
  Black-box conformance ownership surface for `core/conformance`.
  """

  @default_jido_integration_contracts_path "/home/home/p/g/n/jido_integration/core/contracts"
  @published_jido_integration_contracts_requirement "~> 0.1.0"
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

  @spec shared_contract_mode() :: :path_local | :staged_artifact | :published_artifact
  def shared_contract_mode do
    case {requested_contract_mode(), shared_contract_dependency_source()} do
      {:staged_artifact, {:path, _path}} -> :staged_artifact
      {_, {:hex, _requirement}} -> :published_artifact
      _ -> :path_local
    end
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

  defp shared_contract_dependency_source do
    case resolve_contracts_path() do
      nil -> {:hex, @published_jido_integration_contracts_requirement}
      path -> {:path, path}
    end
  end

  defp resolve_contracts_path do
    if contracts_path_resolution_disabled?() do
      nil
    else
      [
        explicit_contracts_path(),
        jido_integration_root_path(),
        @default_jido_integration_contracts_path
      ]
      |> Enum.find_value(&existing_path/1)
    end
  end

  defp explicit_contracts_path do
    case System.get_env("CITADEL_JIDO_INTEGRATION_CONTRACTS_PATH") do
      nil -> nil
      value when value in ["", "0", "false", "disabled", "published"] -> nil
      value -> value
    end
  end

  defp jido_integration_root_path do
    case System.get_env("JIDO_INTEGRATION_PATH") do
      nil -> nil
      value when value in ["", "0", "false", "disabled"] -> nil
      value -> Path.join(value, "core/contracts")
    end
  end

  defp existing_path(nil), do: nil

  defp existing_path(path) do
    expanded = Path.expand(path)

    if File.dir?(expanded) do
      expanded
    else
      nil
    end
  end

  defp contracts_path_resolution_disabled? do
    case System.get_env("CITADEL_JIDO_INTEGRATION_CONTRACTS_PATH") do
      value when is_binary(value) and value not in ["", "0", "false", "disabled", "published"] ->
        false

      value when value in ["0", "false", "disabled", "published"] ->
        true

      _other ->
        disabled_env?(System.get_env("JIDO_INTEGRATION_PATH"))
    end
  end

  defp disabled_env?(value) when value in ["0", "false", "disabled", "published"], do: true
  defp disabled_env?(_value), do: false
end
