defmodule Citadel.ProjectionBridge.MixProject do
  use Mix.Project

  def project do
    [
      app: :citadel_projection_bridge,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Review and derived-state publication adapters for Citadel"
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
      {:citadel_kernel, path: "../../core/citadel_kernel"},
      {:citadel_authority_contract, path: "../../core/authority_contract"},
      {:citadel_observability_contract, path: "../../core/observability_contract"},
      {:jido_integration_contracts, path: "../../core/jido_integration_contracts"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
