defmodule Citadel.ContractCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :citadel_contract_core,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Neutral value helpers and canonical JSON ownership for Citadel"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:jcs, "~> 0.2.0"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
