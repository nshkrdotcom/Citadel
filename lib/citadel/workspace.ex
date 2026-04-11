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
  @proof_package_paths [
    "core/conformance",
    "apps/coding_assist",
    "apps/operator_assist",
    "apps/host_surface_harness"
  ]
  @tooling_project_paths ["."]
  @public_bridge_package_paths [
    "bridges/invocation_bridge",
    "bridges/query_bridge",
    "bridges/signal_bridge",
    "bridges/boundary_bridge",
    "bridges/projection_bridge",
    "bridges/trace_bridge",
    "bridges/memory_bridge"
  ]
  @public_package_paths @package_paths -- @proof_package_paths
  @publication_artifact_id "citadel"
  @publication_manifest_path "packaging/weld/citadel.exs"
  @publication_root_projects ["core/citadel_runtime"]
  @jido_integration_public_repo "https://github.com/agentjido/jido_integration.git"
  @publication_output_docs [
    "README.md",
    "docs/README.md",
    "docs/shared_contract_dependency_strategy.md",
    "docs/workspace_topology.md",
    "docs/publication.md",
    "CHANGELOG.md",
    "LICENSE"
  ]
  @publication_output_assets ["assets/citadel.svg"]

  @toolchain %{
    elixir: "~> 1.19",
    otp: "28"
  }

  @spec package_paths() :: [String.t()]
  def package_paths, do: @package_paths

  @spec package_count() :: pos_integer()
  def package_count, do: length(@package_paths)

  @spec proof_package_paths() :: [String.t()]
  def proof_package_paths, do: @proof_package_paths

  @spec tooling_project_paths() :: [String.t()]
  def tooling_project_paths, do: @tooling_project_paths

  @spec public_bridge_package_paths() :: [String.t()]
  def public_bridge_package_paths, do: @public_bridge_package_paths

  @spec public_package_paths() :: [String.t()]
  def public_package_paths, do: @public_package_paths

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

  @spec publication_artifact_id() :: String.t()
  def publication_artifact_id, do: @publication_artifact_id

  @spec publication_manifest_path() :: String.t()
  def publication_manifest_path, do: @publication_manifest_path

  @spec publication_root_projects() :: [String.t()]
  def publication_root_projects, do: @publication_root_projects

  @spec publication_output_docs() :: [String.t()]
  def publication_output_docs, do: @publication_output_docs

  @spec publication_output_assets() :: [String.t()]
  def publication_output_assets, do: @publication_output_assets

  @spec publication_internal_only_projects() :: [String.t()]
  def publication_internal_only_projects do
    @tooling_project_paths ++ @proof_package_paths
  end

  @spec publication_dependency_declarations() :: keyword()
  def publication_dependency_declarations do
    [
      jido_integration_v2_contracts: publication_shared_contract_dependency_declaration(),
      aitrace: [
        requirement: DependencyResolver.published_aitrace_requirement(),
        opts: []
      ]
    ]
  end

  @spec weld_manifest() :: keyword()
  def weld_manifest do
    [
      workspace: [
        root: "../..",
        project_globs: WorkspaceContract.active_project_globs()
      ],
      classify: [
        tooling: @tooling_project_paths,
        proofs: @proof_package_paths
      ],
      publication: [
        internal_only: publication_internal_only_projects()
      ],
      dependencies: publication_dependency_declarations(),
      artifacts: [
        citadel: [
          roots: @publication_root_projects,
          include: @public_bridge_package_paths,
          package: [
            name: @publication_artifact_id,
            otp_app: :citadel,
            version: "0.1.0",
            elixir: @toolchain.elixir,
            description:
              "Runtime-facing Citadel core packages and bridge adapters projected from the workspace",
            licenses: ["MIT"],
            maintainers: ["nshkrdotcom"],
            links: %{
              "GitHub" => "https://github.com/nshkrdotcom/citadel",
              "Publication Guide" =>
                "https://github.com/nshkrdotcom/citadel/blob/main/docs/publication.md",
              "Changelog" => "https://github.com/nshkrdotcom/citadel/blob/main/CHANGELOG.md"
            },
            docs_main: "workspace_topology"
          ],
          output: [
            docs: @publication_output_docs,
            assets: @publication_output_assets
          ],
          verify: [
            artifact_tests: ["packaging/weld/citadel/test"]
          ]
        ]
      ]
    ]
  end

  defp publication_shared_contract_dependency_declaration do
    case shared_contract_dependency_source() do
      {:hex, requirement} ->
        [requirement: requirement, opts: []]

      {:path, _path} ->
        [
          requirement: nil,
          opts: [
            github: "agentjido/jido_integration",
            sparse: "core/contracts",
            ref: public_git_head!(@jido_integration_public_repo)
          ]
        ]
    end
  end

  defp public_git_head!(remote_url) do
    case System.cmd("git", ["ls-remote", remote_url, "HEAD"], stderr_to_stdout: true) do
      {output, 0} ->
        output
        |> String.split()
        |> List.first()
        |> case do
          nil ->
            raise ArgumentError,
                  "git ls-remote did not return a HEAD revision for #{remote_url}"

          sha ->
            sha
        end

      {output, status} ->
        raise ArgumentError,
              "unable to resolve public git HEAD for #{remote_url} while building the Weld manifest (exit #{status}): #{String.trim(output)}"
    end
  end
end
