defmodule Citadel.DomainSurface.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/nshkrdotcom/citadel"

  def project do
    [
      app: :citadel_domain_surface,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      dialyzer: [plt_add_apps: [:mix]],
      docs: docs(),
      package: package(),
      source_url: @source_url,
      homepage_url: @source_url,
      description: "Typed host-facing domain surface package above the Citadel kernel",
      name: "Citadel Domain Surface"
    ]
  end

  def application do
    [
      extra_applications: [:crypto, :logger]
    ]
  end

  defp deps do
    [
      {:citadel_core, path: "../../core/citadel_core"},
      {:citadel_runtime, path: "../../core/citadel_runtime"},
      {:citadel_host_ingress_bridge, path: "../../bridges/host_ingress_bridge"},
      {:citadel_query_bridge, path: "../../bridges/query_bridge"},
      {:jason, "~> 1.4"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false},
      {:telemetry, "~> 1.4"},
      {:stream_data, "~> 1.1", only: :test},
      {:muex, "~> 0.6", only: [:dev, :test], runtime: false}
    ]
  end

  def cli do
    [
      preferred_envs: [
        credo: :test,
        dialyzer: :test,
        ci: :test,
        docs: :dev,
        hardening: :test,
        "hardening.adversarial": :test,
        "hardening.infrastructure_faults": :test,
        "hardening.mutation": :test,
        "lint.packet_seams": :test,
        "lint.strict": :test,
        "static.analysis": :test
      ]
    ]
  end

  defp aliases do
    mutation_paths = [
      "lib/citadel/domain_surface/router.ex",
      "lib/citadel/domain_surface/support.ex",
      "lib/citadel/domain_surface/orchestration.ex",
      "lib/citadel/domain_surface/error.ex"
    ]

    mutation_aliases =
      Enum.map(mutation_paths, fn path ->
        ~s(muex --files "#{path}" --test-paths "test" --fail-at 100 --optimize-level conservative)
      end)

    [
      "hardening.adversarial": ["test test/citadel_domain_surface_boundary_adversarial_test.exs"],
      "hardening.infrastructure_faults": [
        "cmd ./dev/docker/toxiproxy/run_fault_injection_suite.sh"
      ],
      "hardening.mutation": mutation_aliases,
      hardening: ["hardening.adversarial", "hardening.mutation"],
      "lint.strict": ["credo --config-name strict --all"],
      "static.analysis": [
        "lint.packet_seams",
        "lint.strict",
        "dialyzer --format short"
      ],
      ci: [
        "deps.get",
        "format --check-formatted",
        "compile --warnings-as-errors",
        "static.analysis",
        "test",
        "hardening.mutation"
      ]
    ]
  end

  defp docs do
    [
      main: "Citadel.DomainSurface",
      extras: ["README.md"]
    ]
  end

  defp package do
    [
      name: "citadel_domain_surface",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Citadel Workspace" => @source_url
      }
    ]
  end
end
