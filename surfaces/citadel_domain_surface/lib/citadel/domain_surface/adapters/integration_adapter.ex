defmodule Citadel.DomainSurface.Adapters.IntegrationAdapter do
  @moduledoc """
  Optional adapter seam for lower `jido_integration` work.

  This module exists so the namespace and boundary are explicit, but the repo
  baseline must compile and pass without adding `jido_integration` as a direct
  dependency.
  """

  @behaviour Citadel.DomainSurface.Ports.ExternalIntegration

  alias Citadel.DomainSurface.{Admin, Command, Error, Query}

  @type runtime_opts :: keyword()
  @type response :: %{optional(atom()) => term()}
  @type command_result :: {:ok, response()} | {:error, Error.t()}
  @type admin_result :: {:ok, response()} | {:error, Error.t()}
  @type query_result :: {:ok, response()} | {:error, Error.t()}

  @spec dispatch_command(Command.t()) :: command_result()
  @spec dispatch_command(Admin.t()) :: admin_result()
  @impl true
  def dispatch_command(%Command{} = command) do
    {:error, Error.not_configured(:integration_adapter, operation: {:command, command.name})}
  end

  @impl true
  def dispatch_command(%Admin{} = admin) do
    {:error, Error.not_configured(:integration_adapter, operation: {:admin, admin.name})}
  end

  @spec dispatch_command(Command.t(), runtime_opts()) :: command_result()
  @spec dispatch_command(Admin.t(), runtime_opts()) :: admin_result()
  @impl true
  def dispatch_command(%Command{} = command, _opts) do
    dispatch_command(command)
  end

  def dispatch_command(%Admin{} = admin, _opts) do
    dispatch_command(admin)
  end

  @spec run_query(Query.t()) :: query_result()
  @impl true
  def run_query(%Query{} = query) do
    {:error, Error.not_configured(:integration_adapter, operation: {:query, query.name})}
  end

  @spec run_query(Query.t(), runtime_opts()) :: query_result()
  @impl true
  def run_query(%Query{} = query, _opts) do
    run_query(query)
  end
end
