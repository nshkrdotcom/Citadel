defmodule Citadel.DomainSurface.Adapters.CitadelAdapter.QueryBridgeSurface do
  @moduledoc false

  @behaviour Citadel.DomainSurface.Adapters.CitadelAdapter.QuerySurface

  alias Citadel.QueryBridge

  @type query_payload :: %{optional(atom() | String.t()) => term()}

  @spec fetch_runtime_observation(query_payload(), keyword()) ::
          Citadel.DomainSurface.Adapters.CitadelAdapter.QuerySurface.query_result()
  @impl true
  def fetch_runtime_observation(query, opts) when is_map(query) and is_list(opts) do
    bridge = Keyword.fetch!(opts, :bridge)

    case QueryBridge.fetch_runtime_observation(bridge, query) do
      {:ok, observation, _updated_bridge} -> {:ok, observation}
      {:error, reason, _updated_bridge} -> {:error, reason}
    end
  end

  @spec fetch_boundary_session(query_payload(), keyword()) ::
          Citadel.DomainSurface.Adapters.CitadelAdapter.QuerySurface.query_result()
  @impl true
  def fetch_boundary_session(query, opts) when is_map(query) and is_list(opts) do
    bridge = Keyword.fetch!(opts, :bridge)

    case QueryBridge.fetch_boundary_session(bridge, query) do
      {:ok, descriptor, _updated_bridge} -> {:ok, descriptor}
      {:error, reason, _updated_bridge} -> {:error, reason}
    end
  end
end
