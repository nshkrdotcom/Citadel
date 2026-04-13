defmodule Citadel.DomainSurface.Ports.ExternalIntegration do
  @moduledoc """
  Optional lower seam for durable external-integration truth beneath Domain.

  This seam remains explicitly optional. When it is absent, Domain must fail
  closed rather than inventing durable external evidence, invocation metadata,
  or auth lifecycle state above Citadel.
  """

  alias Citadel.DomainSurface.{Admin, Command, Error, Query}

  @type dispatch_request :: Command.t() | Admin.t()

  @callback dispatch_command(dispatch_request()) :: {:ok, term()} | {:error, Error.t()}
  @callback run_query(Query.t()) :: {:ok, term()} | {:error, Error.t()}

  @optional_callbacks dispatch_command: 2, run_query: 2
  @callback dispatch_command(dispatch_request(), keyword()) :: {:ok, term()} | {:error, Error.t()}
  @callback run_query(Query.t(), keyword()) :: {:ok, term()} | {:error, Error.t()}
end
