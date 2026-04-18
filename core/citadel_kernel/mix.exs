defmodule Citadel.Kernel.MixProject do
  use Mix.Project

  def project do
    [
      app: :citadel_kernel,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Host-stateful session continuity and runtime coordination for Citadel"
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Citadel.Kernel.Application, []}
    ]
  end

  defp deps do
    [
      {:citadel_governance, path: "../citadel_governance"},
      {:citadel_authority_contract, path: "../authority_contract"},
      {:citadel_observability_contract, path: "../observability_contract"},
      {:telemetry, "~> 1.3"},
      {:stream_data, "~> 1.1", only: :test},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
