defmodule Citadel.OperatorAssist.MixProject do
  use Mix.Project

  def project do
    [
      app: :citadel_operator_assist,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Thin operator workflow proof app shell for Citadel"
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
      {:citadel_invocation_bridge, path: "../../bridges/invocation_bridge"},
      {:citadel_query_bridge, path: "../../bridges/query_bridge"},
      {:citadel_signal_bridge, path: "../../bridges/signal_bridge"},
      {:citadel_boundary_bridge, path: "../../bridges/boundary_bridge"},
      {:citadel_projection_bridge, path: "../../bridges/projection_bridge"},
      {:citadel_trace_bridge, path: "../../bridges/trace_bridge"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
