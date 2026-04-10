defmodule Citadel.HostSurfaceHarness.MixProject do
  use Mix.Project

  def project do
    [
      app: :citadel_host_surface_harness,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Thin host/kernel seam proof harness for Citadel"
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
      {:citadel_signal_bridge, path: "../../bridges/signal_bridge"},
      {:citadel_boundary_bridge, path: "../../bridges/boundary_bridge"},
      {:citadel_trace_bridge, path: "../../bridges/trace_bridge"}
    ]
  end
end
