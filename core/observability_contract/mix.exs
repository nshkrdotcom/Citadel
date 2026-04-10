defmodule Citadel.ObservabilityContract.MixProject do
  use Mix.Project

  def project do
    [
      app: :citadel_observability_contract,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Trace and telemetry contract ownership for Citadel"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:citadel_contract_core, path: "../contract_core"}
    ]
  end
end
