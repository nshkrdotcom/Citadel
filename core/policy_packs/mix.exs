defmodule Citadel.PolicyPacks.MixProject do
  use Mix.Project

  def project do
    [
      app: :citadel_policy_packs,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Policy pack ownership and selection surfaces for Citadel"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:citadel_contract_core, path: "../contract_core"},
      {:stream_data, "~> 1.1", only: :test},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
