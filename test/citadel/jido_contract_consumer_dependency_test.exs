defmodule Citadel.JidoContractConsumerDependencyTest do
  use ExUnit.Case, async: true

  @repo_root Path.expand("../..", __DIR__)

  @shared_contract_consumer_mix_files [
    "bridges/invocation_bridge/mix.exs",
    "bridges/jido_integration_bridge/mix.exs",
    "bridges/projection_bridge/mix.exs",
    "core/citadel_governance/mix.exs",
    "core/conformance/mix.exs"
  ]

  test "workspace shared-contract consumers use the canonical dependency resolver" do
    mix_files_with_contract_refs =
      "mix.exs"
      |> tracked_paths_with("jido_integration_contracts")
      |> Enum.reject(&String.starts_with?(&1, "dist/"))
      |> Enum.sort()

    assert mix_files_with_contract_refs == Enum.sort(@shared_contract_consumer_mix_files)

    for mix_file <- @shared_contract_consumer_mix_files do
      source = File.read!(Path.join(@repo_root, mix_file))

      assert String.contains?(
               source,
               "Citadel.Build.DependencyResolver.jido_integration_contracts()"
             )

      refute String.contains?(source, "github.com/agentjido/jido_integration")
      refute String.contains?(source, "core/jido_integration_contracts")
    end
  end

  test "direct surface lock pins upstream sparse core contracts instead of local fork" do
    lock = File.read!(Path.join(@repo_root, "surfaces/citadel_domain_surface/mix.lock"))

    assert String.contains?(lock, "\"jido_integration_contracts\"")
    assert String.contains?(lock, "https://github.com/agentjido/jido_integration.git")
    assert String.contains?(lock, "sparse: \"core/contracts\"")
    refute String.contains?(lock, "core/jido_integration_contracts")
  end

  test "generated projection declares Jido contracts as the canonical external dependency" do
    projection = File.read!(Path.join(@repo_root, "dist/hex/citadel/mix.exs"))

    refute String.contains?(projection, "components/core/jido_integration_contracts")
    assert String.contains?(projection, "{:jido_integration_contracts")
    assert String.contains?(projection, "subdir: \"core/contracts\"")
    refute String.contains?(projection, "jido_integration_v2_contracts")
  end

  test "root workspace resolves external contract dependency through DependencyResolver" do
    resolver = File.read!(Path.join(@repo_root, "lib/citadel/build/dependency_resolver.ex"))
    workspace = File.read!(Path.join(@repo_root, "lib/citadel/workspace.ex"))

    dependency_config =
      File.read!(Path.join(@repo_root, "build_support/dependency_sources.config.exs"))

    assert String.contains?(resolver, "def jido_integration_contracts")
    assert String.contains?(resolver, "apply(:dep")
    assert String.contains?(resolver, "@published_jido_integration_contracts_requirement")
    refute String.contains?(resolver, "JIDO_INTEGRATION_PATH")
    refute String.contains?(resolver, "CITADEL_JIDO_INTEGRATION_CONTRACTS_PATH")
    refute String.contains?(resolver, "System.get_env")
    assert String.contains?(workspace, "DependencyResolver.jido_integration_contracts_source()")
    assert String.contains?(dependency_config, "repo: \"agentjido/jido_integration\"")
    assert String.contains?(dependency_config, "subdir: \"core/contracts\"")
  end

  test "conformance published-contract script does not select dependencies through env" do
    script = File.read!(Path.join(@repo_root, "core/conformance/bin/test_published_contracts.sh"))

    refute String.contains?(script, "JIDO_INTEGRATION_PATH")
    refute String.contains?(script, "CITADEL_JIDO_INTEGRATION_CONTRACTS_PATH")
    refute String.contains?(script, "CITADEL_CONFORMANCE_CONTRACT_MODE")
    assert String.contains?(script, "contract_mode ${mode}")
    assert String.contains?(script, "run_contract_tests published_artifact")
    assert String.contains?(script, "run_contract_tests staged_artifact")
  end

  defp tracked_paths_with(suffix, fragment) do
    {output, 0} = System.cmd("git", ["ls-files", "*#{suffix}"], cd: @repo_root)

    output
    |> String.split("\n", trim: true)
    |> Enum.filter(&String.contains?(File.read!(Path.join(@repo_root, &1)), fragment))
  end
end
