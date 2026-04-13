defmodule Citadel.DomainSurface.Adapters.CitadelAdapter.MaintenanceSurface do
  @moduledoc false

  alias Citadel.DomainSurface.Adapters.CitadelAdapter.RequestContext

  @type operation_result :: {:ok, map()} | {:error, term()}
  @type recovery_result :: {:ok, non_neg_integer() | map()} | {:error, term()}

  @callback inspect_dead_letter(String.t(), RequestContext.t(), keyword()) :: operation_result()
  @callback clear_dead_letter(String.t(), String.t(), RequestContext.t(), keyword()) ::
              operation_result()
  @callback retry_dead_letter(String.t(), String.t(), RequestContext.t(), keyword()) ::
              operation_result()
  @callback replace_dead_letter(
              String.t(),
              map() | keyword() | struct(),
              String.t(),
              RequestContext.t(),
              keyword()
            ) :: operation_result()
  @callback recover_dead_letters(keyword() | map(), term(), RequestContext.t(), keyword()) ::
              recovery_result()
end
