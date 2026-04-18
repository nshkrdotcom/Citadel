defmodule Citadel.SignalBridge.MixProject do
  use Mix.Project

  def project do
    [
      app: :citadel_signal_bridge,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Signal ingress normalization adapters for Citadel"
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
      {:citadel_observability_contract, path: "../../core/observability_contract"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
