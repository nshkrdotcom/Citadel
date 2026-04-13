defmodule Citadel.DomainSurface do
  @moduledoc """
  Public host-facing domain boundary above Citadel.

  `Citadel.DomainSurface` owns semantic commands, queries, routes, lifecycle hooks,
  policy helpers, artifact shaping, and bounded admin surfaces. Host code calls
  these semantic entry points; raw signals remain an internal protocol.
  """

  alias Citadel.DomainSurface.{
    Admin,
    Catalog,
    CapabilityAsset,
    Command,
    Error,
    Query,
    Route,
    Router
  }

  @type trace_id :: String.t()
  @type idempotency_key :: String.t()
  @type payload :: %{optional(atom()) => term()} | struct()
  @type metadata :: %{optional(atom()) => term()}
  @type options :: keyword()
  @type command_result :: {:ok, Command.t()} | {:error, Error.t()}
  @type query_result :: {:ok, Query.t()} | {:error, Error.t()}
  @type admin_result :: {:ok, Admin.t()} | {:error, Error.t()}
  @type dispatch_result :: Router.route_result()
  @type catalog_result :: {:ok, [CapabilityAsset.t()]} | {:error, Error.t()}
  @type tool_manifest_result :: {:ok, [Catalog.tool_manifest_entry()]} | {:error, Error.t()}

  @doc """
  Returns the packet-pinned runtime baseline for this repo.
  """
  @spec runtime_baseline() :: %{elixir: String.t(), otp: pos_integer()}
  def runtime_baseline do
    %{elixir: "~> 1.19", otp: 28}
  end

  @doc """
  Returns the baseline module groups materialized for the proving-ground repo.
  """
  @spec baseline_layout() :: keyword(module())
  def baseline_layout do
    [
      command: Citadel.DomainSurface.Command,
      query: Citadel.DomainSurface.Query,
      route: Citadel.DomainSurface.Route,
      router: Citadel.DomainSurface.Router,
      lifecycle: Citadel.DomainSurface.Lifecycle,
      policy: Citadel.DomainSurface.Policy,
      artifact: Citadel.DomainSurface.Artifact,
      capability_asset: Citadel.DomainSurface.CapabilityAsset,
      catalog: Citadel.DomainSurface.Catalog,
      orchestration: Citadel.DomainSurface.Orchestration,
      error: Citadel.DomainSurface.Error,
      telemetry: Citadel.DomainSurface.Telemetry,
      admin: Citadel.DomainSurface.Admin,
      kernel_runtime_port: Citadel.DomainSurface.Ports.KernelRuntime,
      external_integration_port: Citadel.DomainSurface.Ports.ExternalIntegration,
      citadel_adapter: Citadel.DomainSurface.Adapters.CitadelAdapter,
      integration_adapter: Citadel.DomainSurface.Adapters.IntegrationAdapter,
      example: Citadel.DomainSurface.Examples.ProvingGround,
      example_article_publishing: Citadel.DomainSurface.Examples.ArticlePublishing
    ]
  end

  @doc """
  Builds a semantic Domain command envelope without leaking Citadel internals.
  """
  @spec command(Command.source(), Command.input(), options()) :: command_result()
  def command(commandable, input, opts \\ []) do
    Command.new(commandable, input, opts)
  end

  @doc """
  Builds a semantic Domain query envelope.
  """
  @spec query(Query.source(), Query.params(), options()) :: query_result()
  def query(queryable, params, opts \\ []) do
    Query.new(queryable, params, opts)
  end

  @doc """
  Builds a semantic Domain admin command envelope.
  """
  @spec admin_command(Admin.source(), Admin.input(), options()) :: admin_result()
  def admin_command(adminable, input, opts \\ []) do
    Admin.new(adminable, input, opts)
  end

  @doc """
  Compiles stable typed capability assets from route modules or definitions.
  """
  @spec capability_catalog([Route.source()]) :: catalog_result()
  def capability_catalog(routes) when is_list(routes) do
    Catalog.capability_assets(routes)
  end

  @doc """
  Compiles the stable model-facing tool manifest surface from routes.
  """
  @spec tool_manifest([Route.source()]) :: tool_manifest_result()
  def tool_manifest(routes) when is_list(routes) do
    Catalog.tool_manifest(routes)
  end

  @doc """
  Builds and routes a semantic command through the configured Domain router.
  """
  @spec submit(Command.source(), Command.input(), options()) :: dispatch_result()
  def submit(commandable, input, opts \\ []) do
    with {:ok, command} <- command(commandable, input, opts) do
      Router.route(command, opts)
    end
  end

  @doc """
  Builds and routes a semantic query through the configured Domain router.
  """
  @spec ask(Query.source(), Query.params(), options()) :: dispatch_result()
  def ask(queryable, params, opts \\ []) do
    with {:ok, query} <- query(queryable, params, opts) do
      Router.route(query, opts)
    end
  end

  @doc """
  Builds and routes a semantic admin command through the configured Domain router.
  """
  @spec maintain(Admin.source(), Admin.input(), options()) :: dispatch_result()
  def maintain(adminable, input, opts \\ []) do
    with {:ok, admin} <- admin_command(adminable, input, opts) do
      Router.route(admin, opts)
    end
  end

  @doc """
  Routes a previously built Domain request.
  """
  @spec route(Command.t() | Query.t() | Admin.t(), options()) :: dispatch_result()
  def route(request, opts \\ []) do
    Router.route(request, opts)
  end
end
