unless Code.ensure_loaded?(Citadel.Build.DependencyResolver) do
  Code.require_file("../../lib/citadel/build/dependency_resolver.ex", __DIR__)
end

defmodule Citadel.JidoIntegrationBridge.MixProject do
  use Mix.Project

  def project do
    [
      app: :citadel_jido_integration_bridge,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Citadel-owned lower-gateway bridge adapters"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:citadel_governance, path: "../../core/citadel_governance"},
      {:citadel_authority_contract, path: "../../core/authority_contract"},
      {:citadel_execution_governance_contract, path: "../../core/execution_governance_contract"},
      {:citadel_invocation_bridge, path: "../invocation_bridge"},
      Citadel.Build.DependencyResolver.jido_integration_contracts(),
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
