defmodule Citadel.MixProject do
  use Mix.Project

  def project do
    [
      app: :citadel,
      version: "0.1.0",
      build_path: "_build",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      erlc_paths: [
        "components/bridges/boundary_bridge/src",
        "components/bridges/host_ingress_bridge/src",
        "components/bridges/invocation_bridge/src",
        "components/bridges/jido_integration_bridge/src",
        "components/bridges/memory_bridge/src",
        "components/bridges/projection_bridge/src",
        "components/bridges/query_bridge/src",
        "components/bridges/signal_bridge/src",
        "components/bridges/trace_bridge/src",
        "components/core/authority_contract/src",
        "components/core/citadel_core/src",
        "components/core/citadel_runtime/src",
        "components/core/contract_core/src",
        "components/core/execution_governance_contract/src",
        "components/core/jido_integration_v2_contracts/src",
        "components/core/observability_contract/src",
        "components/core/policy_packs/src"
      ],
      deps: deps(),
      description:
        "Runtime-facing Citadel core packages and bridge adapters projected from the workspace",
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [mod: {Citadel.Application, []}, extra_applications: [:crypto, :logger]]
  end

  def elixirc_paths(:test) do
    base = [
      "lib",
      "config",
      "components/bridges/boundary_bridge/lib",
      "components/bridges/host_ingress_bridge/lib",
      "components/bridges/invocation_bridge/lib",
      "components/bridges/jido_integration_bridge/lib",
      "components/bridges/memory_bridge/lib",
      "components/bridges/projection_bridge/lib",
      "components/bridges/query_bridge/lib",
      "components/bridges/signal_bridge/lib",
      "components/bridges/trace_bridge/lib",
      "components/core/authority_contract/lib",
      "components/core/citadel_core/lib",
      "components/core/citadel_runtime/lib",
      "components/core/contract_core/lib",
      "components/core/execution_governance_contract/lib",
      "components/core/jido_integration_v2_contracts/lib",
      "components/core/observability_contract/lib",
      "components/core/policy_packs/lib"
    ]

    if File.dir?("test/support") do
      base ++ ["test/support"]
    else
      base
    end
  end

  def elixirc_paths(_env),
    do: [
      "lib",
      "config",
      "components/bridges/boundary_bridge/lib",
      "components/bridges/host_ingress_bridge/lib",
      "components/bridges/invocation_bridge/lib",
      "components/bridges/jido_integration_bridge/lib",
      "components/bridges/memory_bridge/lib",
      "components/bridges/projection_bridge/lib",
      "components/bridges/query_bridge/lib",
      "components/bridges/signal_bridge/lib",
      "components/bridges/trace_bridge/lib",
      "components/core/authority_contract/lib",
      "components/core/citadel_core/lib",
      "components/core/citadel_runtime/lib",
      "components/core/contract_core/lib",
      "components/core/execution_governance_contract/lib",
      "components/core/jido_integration_v2_contracts/lib",
      "components/core/observability_contract/lib",
      "components/core/policy_packs/lib"
    ]

  defp deps do
    [
      {:aitrace, "~> 0.1.0"},
      {:jcs, "~> 0.2.0"},
      {:telemetry, "~> 1.3"},
      {:zoi, "~> 0.17"},
      {:ex_doc, "~> 0.40", [only: :dev, runtime: false]}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["nshkrdotcom"],
      links: %{
        "Changelog" => "https://github.com/nshkrdotcom/citadel/blob/main/CHANGELOG.md",
        "GitHub" => "https://github.com/nshkrdotcom/citadel",
        "Publication Guide" =>
          "https://github.com/nshkrdotcom/citadel/blob/main/docs/publication.md"
      },
      files: [
        ".credo.exs",
        ".formatter.exs",
        "CHANGELOG.md",
        "LICENSE",
        "README.md",
        "assets/citadel.svg",
        "components/bridges/boundary_bridge",
        "components/bridges/host_ingress_bridge",
        "components/bridges/invocation_bridge",
        "components/bridges/jido_integration_bridge",
        "components/bridges/memory_bridge",
        "components/bridges/projection_bridge",
        "components/bridges/query_bridge",
        "components/bridges/signal_bridge",
        "components/bridges/trace_bridge",
        "components/core/authority_contract",
        "components/core/citadel_core",
        "components/core/citadel_runtime",
        "components/core/contract_core",
        "components/core/execution_governance_contract",
        "components/core/jido_integration_v2_contracts",
        "components/core/observability_contract",
        "components/core/policy_packs",
        "config",
        "docs/README.md",
        "docs/publication.md",
        "docs/shared_contract_dependency_strategy.md",
        "docs/workspace_topology.md",
        "lib",
        "mix.exs",
        "projection.lock.json"
      ]
    ]
  end

  defp docs do
    [
      main: "workspace_topology",
      extras: [
        "CHANGELOG.md",
        "LICENSE",
        "README.md",
        "docs/README.md",
        "docs/publication.md",
        "docs/shared_contract_dependency_strategy.md",
        "docs/workspace_topology.md"
      ]
    ]
  end
end
