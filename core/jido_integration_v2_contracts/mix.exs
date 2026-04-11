defmodule Jido.Integration.V2.Contracts.MixProject do
  use Mix.Project

  def project do
    [
      app: :jido_integration_v2_contracts,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Citadel-local higher-order Jido Integration V2 contract slice"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps, do: []
end
