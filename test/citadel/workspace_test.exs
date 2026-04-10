defmodule Citadel.WorkspaceTest do
  use ExUnit.Case, async: true

  alias Citadel.Workspace

  test "tracks the packet workspace package contract on disk" do
    assert Workspace.package_count() == 17
    assert Workspace.package_count() == length(Workspace.package_paths())
    assert "apps/host_surface_harness" in Workspace.package_paths()
    assert Workspace.missing_package_paths() == []

    assert Enum.all?(Workspace.package_paths(), fn path ->
             File.regular?(Path.join(path, "mix.exs")) and
               File.regular?(Path.join(path, "README.md"))
           end)
  end

  test "pins the packet toolchain baseline" do
    assert Workspace.toolchain() == %{elixir: "~> 1.19", otp: "28"}
  end

  test "exposes an explicit shared-contract dependency strategy" do
    assert match?({:path, _path}, Workspace.shared_contract_dependency_source()) or
             match?({:hex, "~> 0.1.0"}, Workspace.shared_contract_dependency_source())
  end
end
