defmodule Citadel.PublicationSurfaceTest do
  use ExUnit.Case, async: true

  test "welded artifact keeps runtime-facing packages and excludes proof packages" do
    assert Mix.Project.config()[:app] == :citadel

    assert Code.ensure_loaded?(Citadel.Runtime)
    assert Code.ensure_loaded?(Citadel.TraceBridge)
    assert Code.ensure_loaded?(Citadel.ProjectionBridge)
    assert Code.ensure_loaded?(Citadel.InvocationBridge)
    assert Code.ensure_loaded?(Citadel.QueryBridge)
    assert Code.ensure_loaded?(Citadel.SignalBridge)
    assert Code.ensure_loaded?(Citadel.BoundaryBridge)
    assert Code.ensure_loaded?(Citadel.MemoryBridge)

    refute Code.ensure_loaded?(Citadel.Conformance)
    refute Code.ensure_loaded?(Citadel.Apps.HostSurfaceHarness)
    refute Code.ensure_loaded?(Citadel.Apps.CodingAssist)
    refute Code.ensure_loaded?(Citadel.Apps.OperatorAssist)

    assert File.dir?("components/core/citadel_runtime")
    assert File.dir?("components/bridges/trace_bridge")
    refute File.dir?("components/core/conformance")
    refute File.dir?("components/apps/host_surface_harness")
  end

  test "welded artifact canonicalizes publishable bridge dependencies" do
    deps = Mix.Project.config()[:deps]

    assert dependency_tuple(deps, :aitrace) == {:aitrace, "~> 0.1.0", []}

    case dependency_tuple(deps, :jido_integration_v2_contracts) do
      {:jido_integration_v2_contracts, requirement, []} when is_binary(requirement) ->
        :ok

      {:jido_integration_v2_contracts, nil, opts} ->
        assert opts[:github] == "agentjido/jido_integration"
        assert opts[:sparse] == "core/contracts"
        assert is_binary(opts[:ref])
        assert byte_size(opts[:ref]) == 40
        refute Keyword.has_key?(opts, :path)
    end
  end

  defp dependency_tuple(deps, app) do
    Enum.find_value(deps, fn
      {^app, requirement} when is_binary(requirement) ->
        {app, requirement, []}

      {^app, opts} when is_list(opts) ->
        {app, nil, opts}

      {^app, requirement, opts} when is_binary(requirement) and is_list(opts) ->
        {app, requirement, opts}

      _other ->
        nil
    end)
  end
end
