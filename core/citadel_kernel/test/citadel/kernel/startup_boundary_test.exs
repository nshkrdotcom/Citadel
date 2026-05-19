defmodule Citadel.Kernel.StartupBoundaryTest do
  use ExUnit.Case, async: true

  alias Citadel.Kernel.SignalIngress.PartitionWorker

  @runtime_library_sources [
    "lib/citadel/kernel/signal_ingress.ex",
    "lib/citadel/kernel/boundary_lease_tracker.ex"
  ]

  test "runtime library paths do not implicitly start the Citadel kernel application" do
    Enum.each(@runtime_library_sources, fn path ->
      source = File.read!(path)

      refute String.contains?(source, "Application.ensure_all_started"),
             "#{path} must require explicit supervision instead of booting the application"
    end)
  end

  test "partition workers expose supervised entrypoints only" do
    assert Code.ensure_loaded?(PartitionWorker)
    assert function_exported?(PartitionWorker, :start_link, 1)
    assert function_exported?(PartitionWorker, :child_spec, 1)
    refute function_exported?(PartitionWorker, :start, 1)
  end
end
