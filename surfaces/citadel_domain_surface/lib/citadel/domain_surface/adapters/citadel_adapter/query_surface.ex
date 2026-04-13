defmodule Citadel.DomainSurface.Adapters.CitadelAdapter.QuerySurface do
  @moduledoc false

  alias Citadel.BoundarySessionDescriptor.V1, as: BoundarySessionDescriptorV1
  alias Citadel.RuntimeObservation

  @type query_result ::
          {:ok, RuntimeObservation.t() | BoundarySessionDescriptorV1.t() | map()}
          | {:error, term()}

  @callback fetch_runtime_observation(map(), keyword()) :: query_result()
  @callback fetch_boundary_session(map(), keyword()) :: query_result()
end
