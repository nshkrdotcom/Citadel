defmodule Citadel.InvocationBridge.MixProject do
  use Mix.Project

  def project do
    [
      app: :citadel_invocation_bridge,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Invocation handoff adapters for Citadel"
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
      {:citadel_runtime, path: "../../core/citadel_runtime"},
      {:citadel_authority_contract, path: "../../core/authority_contract"},
      {:citadel_observability_contract, path: "../../core/observability_contract"},
      {:jido_integration_v2_contracts, path: "../../core/jido_integration_v2_contracts"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
