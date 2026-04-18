defmodule Citadel.PublicationSurfaceTest do
  use ExUnit.Case, async: true

  test "welded artifact keeps runtime-facing packages and excludes proof packages" do
    assert Mix.Project.config()[:app] == :citadel

    assert Code.ensure_loaded?(Citadel.Kernel)
    assert Code.ensure_loaded?(Citadel.HostIngress)
    assert Code.ensure_loaded?(Citadel.TraceBridge)
    assert Code.ensure_loaded?(Citadel.ProjectionBridge)
    assert Code.ensure_loaded?(Citadel.InvocationBridge)
    assert Code.ensure_loaded?(Citadel.QueryBridge)
    assert Code.ensure_loaded?(Citadel.SignalBridge)
    assert Code.ensure_loaded?(Citadel.BoundaryBridge)

    refute Code.ensure_loaded?(Citadel.Conformance)
    refute Code.ensure_loaded?(Citadel.Apps.HostSurfaceHarness)
    refute Code.ensure_loaded?(Citadel.Apps.CodingAssist)
    refute Code.ensure_loaded?(Citadel.Apps.OperatorAssist)

    assert File.dir?("components/core/citadel_kernel")
    assert File.dir?("components/bridges/host_ingress_bridge")
    assert File.dir?("components/core/jido_integration_contracts")
    assert File.dir?("components/bridges/trace_bridge")
    refute File.dir?("components/core/conformance")
    refute File.dir?("components/apps/host_surface_harness")
  end

  test "welded artifact only retains publishable external dependencies" do
    deps = Mix.Project.config()[:deps]

    assert dependency_tuple(deps, :aitrace) == {:aitrace, "~> 0.1.0", []}
    refute dependency_tuple(deps, :jido_integration_contracts)
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
