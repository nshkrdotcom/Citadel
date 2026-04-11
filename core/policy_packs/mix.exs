defmodule Citadel.PolicyPacks.MixProject do
  use Mix.Project

  def project do
    [
      app: :citadel_policy_packs,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: "Policy pack ownership and selection surfaces for Citadel"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [preferred_envs: preferred_cli_env()]
  end

  defp deps do
    [
      {:citadel_contract_core, path: "../contract_core"},
      {:stream_data, "~> 1.1", only: :test},
      {:muex, "~> 0.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      "hardening.adversarial": ["test test/citadel/policy_packs_adversarial_test.exs"],
      "hardening.mutation": [
        ~s(muex --files "lib/citadel/policy_packs.ex" --test-paths "test/citadel" --fail-at 100 --optimize-level conservative)
      ],
      hardening: ["hardening.adversarial", "hardening.mutation"]
    ]
  end

  defp preferred_cli_env do
    [
      muex: :test,
      "hardening.adversarial": :test,
      "hardening.mutation": :test,
      hardening: :test
    ]
  end
end
