defmodule Citadel.DomainSurface.CapabilityAsset do
  @moduledoc """
  Stable typed capability asset compiled from a route definition.
  """

  alias Citadel.DomainSurface.{Error, Orchestration, Route}

  @enforce_keys [
    :route_name,
    :request_type,
    :operation,
    :dispatch_via,
    :version,
    :schema_hash,
    :orchestration
  ]
  defstruct [
    :route_name,
    :request_type,
    :operation,
    :dispatch_via,
    :version,
    :schema_hash,
    :description,
    :orchestration,
    metadata: %{},
    semantic_metadata: %{},
    tool_manifest: %{},
    read_descriptor: nil,
    operator_hints: %{}
  ]

  @type t :: %__MODULE__{
          route_name: atom(),
          request_type: Route.Definition.request_type(),
          operation: atom(),
          dispatch_via: Route.Definition.dispatch_via(),
          version: Route.Definition.version(),
          schema_hash: Route.Definition.schema_hash(),
          description: String.t() | nil,
          orchestration: Orchestration.t(),
          metadata: map(),
          semantic_metadata: map(),
          tool_manifest: map(),
          read_descriptor: map() | nil,
          operator_hints: map()
        }

  @spec from_route(Route.source()) :: {:ok, t()} | {:error, Error.t()}
  def from_route(source) do
    with {:ok, definition} <- Route.fetch_definition(source) do
      {:ok,
       %__MODULE__{
         route_name: definition.name,
         request_type: definition.request_type,
         operation: definition.operation,
         dispatch_via: definition.dispatch_via,
         version: definition.version,
         schema_hash: definition.schema_hash,
         description: definition.description,
         orchestration: definition.orchestration,
         metadata: definition.metadata,
         semantic_metadata: definition.semantic_metadata,
         tool_manifest: definition.tool_manifest,
         read_descriptor: definition.read_descriptor,
         operator_hints: definition.operator_hints
       }}
    end
  end
end
