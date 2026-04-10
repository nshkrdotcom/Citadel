defmodule Citadel.Runtime.MixProject do
  use Mix.Project

  def project do
    [
      app: :citadel_runtime,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Runtime coordination and local ownership processes for Citadel"
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Citadel.Runtime.Application, []}
    ]
  end

  defp deps do
    [
      {:citadel_core, path: "../citadel_core"},
      {:citadel_authority_contract, path: "../authority_contract"},
      {:citadel_observability_contract, path: "../observability_contract"}
    ]
  end
end
