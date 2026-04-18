defmodule Jido.Integration.V2.Contracts.MixProject do
  use Mix.Project

  def project do
    [
      app: :jido_integration_contracts,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: false,
      deps: deps(),
      description: "Citadel-local higher-order Jido Integration V2 contract slice"
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  defp deps do
    [
      {:jcs, "~> 0.2.0"},
      {:zoi, "~> 0.17"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
