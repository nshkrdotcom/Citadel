unless Code.ensure_loaded?(Citadel.Build.WorkspaceContract) do
  Code.require_file("build_support/workspace_contract.exs", __DIR__)
end

defmodule Citadel.Workspace.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/nshkrdotcom/citadel"

  alias Citadel.Build.WorkspaceContract

  def project do
    [
      app: :citadel_workspace,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      blitz_workspace: blitz_workspace(),
      docs: docs(),
      source_url: @source_url,
      name: "Citadel Workspace",
      description: "Tooling root for the Citadel non-umbrella monorepo"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:blitz, "~> 0.2.0", runtime: false},
      {:weld, "~> 0.4.0", runtime: false},
      {:libgraph, "~> 0.16.1-mg.2", hex: :multigraph, app: false, override: true},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    monorepo_aliases = [
      "monorepo.deps.get": ["blitz.workspace deps_get"],
      "monorepo.format": ["blitz.workspace format"],
      "monorepo.compile": ["blitz.workspace compile"],
      "monorepo.test": ["blitz.workspace test"]
    ]

    mr_aliases =
      ~w[deps.get format compile test]
      |> Enum.map(fn task -> {:"mr.#{task}", ["monorepo.#{task}"]} end)

    [
      ci: [
        "deps.get",
        "monorepo.deps.get",
        "monorepo.format --check-formatted",
        "monorepo.compile",
        "monorepo.test"
      ],
      "docs.root": ["docs"]
    ] ++ monorepo_aliases ++ mr_aliases
  end

  defp blitz_workspace do
    [
      root: __DIR__,
      projects: WorkspaceContract.active_project_globs(),
      isolation: [
        deps_path: true,
        build_path: true,
        lockfile: true,
        hex_home: "_build/hex"
      ],
      parallelism: [
        env: "CITADEL_MONOREPO_MAX_CONCURRENCY",
        multiplier: :auto,
        base: [
          deps_get: 3,
          format: 4,
          compile: 2,
          test: 2
        ],
        overrides: []
      ],
      tasks: [
        deps_get: [args: ["deps.get"], preflight?: false],
        format: [args: ["format"]],
        compile: [args: ["compile", "--warnings-as-errors"]],
        test: [args: ["test"], mix_env: "test", color: true]
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      name: "Citadel Workspace",
      logo: "assets/citadel.svg",
      assets: %{"assets" => "assets"},
      source_ref: "v#{@version}",
      source_url: @source_url,
      homepage_url: @source_url,
      extras: [
        "README.md",
        "docs/README.md",
        "docs/workspace_topology.md",
        "docs/shared_contract_dependency_strategy.md",
        "CHANGELOG.md",
        "LICENSE"
      ],
      groups_for_extras: [
        Overview: ["README.md", "docs/README.md"],
        Architecture: ["docs/workspace_topology.md"],
        Contracts: ["docs/shared_contract_dependency_strategy.md"],
        Project: ["CHANGELOG.md", "LICENSE"]
      ]
    ]
  end
end
