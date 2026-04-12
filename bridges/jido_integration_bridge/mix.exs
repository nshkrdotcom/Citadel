defmodule Citadel.JidoIntegrationBridge.MixProject do
  use Mix.Project

  def project do
    [
      app: :citadel_jido_integration_bridge,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Citadel-owned Brain-to-Jido Integration bridge adapters"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:citadel_core, path: "../../core/citadel_core"},
      {:citadel_authority_contract, path: "../../core/authority_contract"},
      {:citadel_execution_governance_contract, path: "../../core/execution_governance_contract"},
      {:citadel_invocation_bridge, path: "../invocation_bridge"},
      {:jido_integration_v2_contracts, path: "../../core/jido_integration_v2_contracts"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
