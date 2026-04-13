defmodule Citadel.DomainSurface.Catalog do
  @moduledoc """
  Stable catalog and tool-manifest compilation for typed route assets.
  """

  alias Citadel.DomainSurface.{CapabilityAsset, Error}

  @type source :: Citadel.DomainSurface.Route.source()
  @type tool_manifest_entry :: %{
          route_name: atom(),
          request_type: atom(),
          dispatch_via: atom(),
          version: String.t(),
          schema_hash: String.t(),
          description: String.t() | nil,
          semantic_metadata: map(),
          tool_manifest: map(),
          read_descriptor: map() | nil,
          operator_hints: map()
        }

  @spec capability_assets([source()]) :: {:ok, [CapabilityAsset.t()]} | {:error, Error.t()}
  def capability_assets(sources) when is_list(sources) do
    with {:ok, assets} <- compile_assets(sources),
         :ok <- ensure_unique_route_names(assets) do
      {:ok, Enum.sort_by(assets, &Atom.to_string(&1.route_name))}
    end
  end

  @spec tool_manifest([source()]) :: {:ok, [tool_manifest_entry()]} | {:error, Error.t()}
  def tool_manifest(sources) when is_list(sources) do
    with {:ok, assets} <- capability_assets(sources) do
      {:ok,
       Enum.map(assets, fn asset ->
         %{
           route_name: asset.route_name,
           request_type: asset.request_type,
           dispatch_via: asset.dispatch_via,
           version: asset.version,
           schema_hash: asset.schema_hash,
           description: asset.description,
           semantic_metadata: asset.semantic_metadata,
           tool_manifest: asset.tool_manifest,
           read_descriptor: asset.read_descriptor,
           operator_hints: asset.operator_hints
         }
       end)}
    end
  end

  defp compile_assets(sources) do
    Enum.reduce_while(sources, {:ok, []}, fn source, {:ok, assets} ->
      case CapabilityAsset.from_route(source) do
        {:ok, asset} -> {:cont, {:ok, [asset | assets]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp ensure_unique_route_names(assets) do
    names = Enum.map(assets, & &1.route_name)

    if length(names) == length(Enum.uniq(names)) do
      :ok
    else
      {:error,
       Error.validation(
         :duplicate_route,
         "catalog sources must not contain duplicate route names",
         route_names: names
       )}
    end
  end
end
