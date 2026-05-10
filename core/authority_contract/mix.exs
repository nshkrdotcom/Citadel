unless Code.ensure_loaded?(Citadel.Build.DependencyResolver) do
  Code.require_file("../../lib/citadel/build/dependency_resolver.ex", __DIR__)
end

defmodule Citadel.AuthorityContract.MixProject do
  use Mix.Project

  alias Citadel.Build.DependencyResolver

  def project do
    [
      app: :citadel_authority_contract,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Brain-authored authority packet ownership for Citadel"
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
      DependencyResolver.execution_plane(),
      DependencyResolver.ground_plane_persistence_policy(),
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
