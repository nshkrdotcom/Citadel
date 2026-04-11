defmodule Citadel.WorkspaceTest do
  use ExUnit.Case, async: true

  alias Citadel.Workspace
  alias Weld

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

  test "defines a derivative welded publication boundary" do
    assert Workspace.proof_package_paths() == [
             "core/conformance",
             "apps/coding_assist",
             "apps/operator_assist",
             "apps/host_surface_harness"
           ]

    assert Workspace.tooling_project_paths() == ["."]
    assert Workspace.publication_artifact_id() == "citadel"
    assert Workspace.publication_manifest_path() == "packaging/weld/citadel.exs"
    assert Workspace.publication_root_projects() == ["core/citadel_runtime"]

    assert Enum.sort(Workspace.public_bridge_package_paths()) ==
             Enum.sort(
               Enum.filter(Workspace.package_paths(), &String.starts_with?(&1, "bridges/"))
             )

    refute "core/conformance" in Workspace.public_package_paths()
    refute "apps/host_surface_harness" in Workspace.public_package_paths()
  end

  test "weld manifest keeps publication derivative of the workspace architecture" do
    result = Weld.inspect!(Workspace.publication_manifest_path())

    assert result.manifest.artifact == "citadel"
    assert result.artifact.roots == Workspace.publication_root_projects()
    assert result.violations == []

    assert "." in result.classifications.tooling
    assert "core/conformance" in result.classifications.proof
    assert "apps/host_surface_harness" in result.classifications.proof

    assert "core/citadel_runtime" in result.artifact.selected_projects
    assert "bridges/trace_bridge" in result.artifact.selected_projects
    assert "bridges/projection_bridge" in result.artifact.selected_projects
    refute "core/conformance" in result.artifact.selected_projects
    refute "apps/host_surface_harness" in result.artifact.selected_projects

    assert "aitrace" in result.artifact.external_deps
    assert "jido_integration_v2_contracts" in result.artifact.external_deps
  end
end
