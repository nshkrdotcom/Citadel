defmodule Citadel.DomainSurface.CapabilityCatalogTest do
  use ExUnit.Case, async: true

  alias Citadel.DomainSurface, as: Domain
  alias Citadel.DomainSurface.Examples.ArticlePublishing
  alias Citadel.DomainSurface.Examples.ProvingGround

  defmodule CatalogRoutes do
    @moduledoc false

    alias Citadel.DomainSurface.Route

    defmodule Alpha do
      @moduledoc false
      @behaviour Route

      def definition do
        Route.definition!(
          name: :alpha,
          request_type: :command,
          operation: :alpha,
          dispatch_via: :kernel_runtime,
          version: "1.0.0",
          description: "Alpha route",
          semantic_metadata: %{intent: "alpha"},
          tool_manifest: %{summary: "alpha tool"},
          operator_hints: %{queue: :primary}
        )
      end
    end

    defmodule AlphaV2 do
      @moduledoc false
      @behaviour Route

      def definition do
        Route.definition!(
          name: :alpha,
          request_type: :command,
          operation: :alpha,
          dispatch_via: :kernel_runtime,
          version: "2.0.0",
          description: "Alpha route",
          semantic_metadata: %{intent: "alpha"},
          tool_manifest: %{summary: "alpha tool"},
          operator_hints: %{queue: :primary}
        )
      end
    end
  end

  test "compiles stable capability assets from typed route modules" do
    routes = [
      ProvingGround.Routes.WorkspaceStatus,
      ProvingGround.Routes.CompileWorkspace,
      ArticlePublishing.Routes.PublicationStatus
    ]

    assert {:ok, assets} = Domain.capability_catalog(routes)

    assert Enum.map(assets, & &1.route_name) == [
             :compile_workspace,
             :publication_status,
             :workspace_status
           ]

    compile_workspace = Enum.find(assets, &(&1.route_name == :compile_workspace))

    assert compile_workspace.version == "1.0.0"
    assert compile_workspace.semantic_metadata[:category] == :workspace

    assert compile_workspace.tool_manifest[:summary] ==
             "Compile a workspace and apply the resulting patch"

    assert compile_workspace.operator_hints[:review_bundle] == :workspace_patch

    workspace_status = Enum.find(assets, &(&1.route_name == :workspace_status))

    assert workspace_status.read_descriptor[:projection] == :workspace_status
    assert workspace_status.read_descriptor[:identity_fields] == [:workspace_id]
  end

  test "compiles a model-facing tool manifest with stable route identity" do
    routes = [ProvingGround.Routes.CompileWorkspace, ProvingGround.Routes.WorkspaceStatus]

    assert {:ok, manifest} = Domain.tool_manifest(routes)

    assert [
             %{
               route_name: :compile_workspace,
               version: "1.0.0",
               schema_hash: compile_hash,
               tool_manifest: %{summary: "Compile a workspace and apply the resulting patch"}
             },
             %{
               route_name: :workspace_status,
               version: "1.0.0",
               schema_hash: workspace_hash,
               read_descriptor: %{projection: :workspace_status}
             }
           ] = manifest

    assert is_binary(compile_hash)
    assert String.length(compile_hash) == 64
    assert is_binary(workspace_hash)
    assert String.length(workspace_hash) == 64
  end

  test "route schema hash changes when the route version changes" do
    assert Domain.Route.schema_hash(CatalogRoutes.Alpha) !=
             Domain.Route.schema_hash(CatalogRoutes.AlphaV2)
  end

  test "rejects duplicate route names inside one compiled catalog" do
    assert {:error, error} =
             Domain.capability_catalog([
               CatalogRoutes.Alpha,
               CatalogRoutes.AlphaV2
             ])

    assert error.code == :duplicate_route
  end
end
