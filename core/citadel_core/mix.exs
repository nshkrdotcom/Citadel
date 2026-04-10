unless Code.ensure_loaded?(Citadel.Build.DependencyResolver) do
  Code.require_file("../../build_support/dependency_resolver.exs", __DIR__)
end

defmodule Citadel.Core.MixProject do
  use Mix.Project

  alias Citadel.Build.DependencyResolver

  def project do
    [
      app: :citadel_core,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Pure values and deterministic kernel logic surfaces for Citadel"
    ]
  end

  def application do
    [
      extra_applications: [:crypto, :logger]
    ]
  end

  defp deps do
    [
      {:citadel_contract_core, path: "../contract_core"},
      {:citadel_authority_contract, path: "../authority_contract"},
      {:citadel_observability_contract, path: "../observability_contract"},
      {:citadel_policy_packs, path: "../policy_packs"},
      DependencyResolver.jido_integration_v2_contracts()
    ]
  end
end
