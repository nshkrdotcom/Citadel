defmodule Citadel.BoundaryBridge.MixProject do
  use Mix.Project

  def project do
    [
      app: :citadel_boundary_bridge,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Boundary lifecycle adapters for Citadel"
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
      {:citadel_authority_contract, path: "../../core/authority_contract"}
    ]
  end
end
