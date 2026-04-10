unless Code.ensure_loaded?(Citadel.Build.DependencyResolver) do
  Code.require_file("../../build_support/dependency_resolver.exs", __DIR__)
end

defmodule Citadel.TraceBridge.MixProject do
  use Mix.Project

  alias Citadel.Build.DependencyResolver

  def project do
    [
      app: :citadel_trace_bridge,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Trace publication adapters for Citadel"
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
      {:citadel_observability_contract, path: "../../core/observability_contract"},
      DependencyResolver.aitrace()
    ]
  end
end
