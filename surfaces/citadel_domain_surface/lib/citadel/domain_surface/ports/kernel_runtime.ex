defmodule Citadel.DomainSurface.Ports.KernelRuntime do
  @moduledoc """
  Narrow port for the required Citadel-facing kernel runtime adapter.
  """

  alias Citadel.DomainSurface.{Admin, Command, Error, Query}

  @type dispatch_request :: Command.t() | Admin.t()

  @callback dispatch_command(dispatch_request()) :: {:ok, term()} | {:error, Error.t()}
  @callback run_query(Query.t()) :: {:ok, term()} | {:error, Error.t()}

  @optional_callbacks dispatch_command: 2, run_query: 2
  @callback dispatch_command(dispatch_request(), keyword()) :: {:ok, term()} | {:error, Error.t()}
  @callback run_query(Query.t(), keyword()) :: {:ok, term()} | {:error, Error.t()}
end
