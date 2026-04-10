unless Code.ensure_loaded?(Citadel.Build.WorkspaceContract) do
  Code.require_file("../../build_support/workspace_contract.exs", __DIR__)
end

unless Code.ensure_loaded?(Citadel.Build.DependencyResolver) do
  Code.require_file("../../build_support/dependency_resolver.exs", __DIR__)
end

defmodule Citadel.Workspace do
  @moduledoc """
  Packet-aligned metadata for the Citadel non-umbrella workspace.

  This root module exists so the workspace tooling project has a concrete,
  testable surface without pretending to be the old single-package runtime.
  """

  alias Citadel.Build.DependencyResolver
  alias Citadel.Build.WorkspaceContract

  @package_paths WorkspaceContract.package_paths()

  @toolchain %{
    elixir: "~> 1.19",
    otp: "28"
  }

  @spec package_paths() :: [String.t()]
  def package_paths, do: @package_paths

  @spec package_count() :: pos_integer()
  def package_count, do: length(@package_paths)

  @spec missing_package_paths() :: [String.t()]
  def missing_package_paths do
    @package_paths
    |> Enum.reject(&File.regular?(Path.join(&1, "mix.exs")))
  end

  @spec shared_contract_dependency_source() :: {:hex, String.t()} | {:path, String.t()}
  def shared_contract_dependency_source do
    DependencyResolver.jido_integration_v2_contracts_source()
  end

  @spec toolchain() :: %{elixir: String.t(), otp: String.t()}
  def toolchain, do: @toolchain
end
