defmodule Citadel.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :citadel,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      description: "The command and control layer for the AI-powered enterprise.",
      package: package(),
      docs: docs(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Citadel.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp package do
    [
      files: [
        "lib",
        ".formatter.exs",
        "mix.exs",
        "README.md",
        "CHANGELOG.md",
        "LICENSE",
        "assets/*.svg"
      ],
      maintainers: ["nshkrdotcom <ZeroTrust@NSHkr.com>"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/nshkrdotcom/Citadel"}
    ]
  end

  defp docs do
    [
      main: "readme",
      name: "Citadel",
      logo: "assets/citadel.svg",
      assets: %{"assets" => "assets"},
      source_ref: "v#{@version}",
      source_url: "https://github.com/nshkrdotcom/Citadel",
      homepage_url: "https://github.com/nshkrdotcom/Citadel",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"],
      groups_for_extras: [
        Overview: ["README.md"],
        Project: ["CHANGELOG.md", "LICENSE"]
      ]
    ]
  end
end
