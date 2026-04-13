defmodule Citadel.DomainSurface.Router do
  @moduledoc """
  Explicit routing seam from the Domain boundary into configured lower ports.

  Routing remains semantic and host-facing. Unsupported orchestration is
  rejected explicitly, and the router never invents hidden in-memory saga
  ownership to bridge gaps in durable backing.
  """

  alias Citadel.DomainSurface.{
    Admin,
    Command,
    Error,
    Lifecycle,
    Policy,
    Query,
    Route,
    Support,
    Telemetry
  }

  @type request :: Command.t() | Query.t() | Admin.t()
  @type malformed_request :: nil | atom() | binary() | number() | tuple() | list() | map()
  @type options_input :: nil | atom() | binary() | number() | tuple() | list() | map()
  @type response :: term()
  @type route_result :: {:ok, response()} | {:error, Error.t()}

  @spec resolve(request()) :: {:ok, Route.t()} | {:error, Error.t()}
  def resolve(%Command{route: %Route.Definition{} = route}), do: {:ok, route}
  def resolve(%Query{route: %Route.Definition{} = route}), do: {:ok, route}
  def resolve(%Admin{route: %Route.Definition{} = route}), do: {:ok, route}

  @spec route(request() | malformed_request(), options_input()) :: route_result()
  def route(request, opts \\ []) do
    with {:ok, opts} <- Support.normalize_options(opts) do
      do_route(request, opts)
    end
  end

  defp do_route(%Command{} = command, opts) do
    with {:ok, route} <- resolve(command),
         {:ok, command, context} <-
           Lifecycle.run_before_validation(command.definition.lifecycle, command, command.context),
         :ok <- Policy.evaluate_all(command.definition.policies, command, context),
         {:ok, command, context} <-
           Lifecycle.run_before_dispatch(command.definition.lifecycle, command, context),
         :ok <- Telemetry.command_submit(command),
         {:ok, result} <- dispatch_command(route, command, opts),
         :ok <- Telemetry.maybe_emit_command_idempotency(command, result),
         {:ok, final_result} <-
           Lifecycle.run_after_dispatch(command.definition.lifecycle, command, result, context) do
      {:ok, final_result}
    else
      {:error, %Error{} = error} ->
        Telemetry.maybe_emit_command_rejection(command, error)
        Telemetry.maybe_emit_adapter_error(command, error)

        Lifecycle.notify_after_error(
          command.definition.lifecycle,
          command,
          error,
          command.context
        )

        {:error, error}
    end
  end

  defp do_route(%Query{} = query, opts) do
    with {:ok, route} <- resolve(query),
         {:ok, query, context} <-
           Lifecycle.run_before_validation(query.definition.lifecycle, query, query.context),
         :ok <- Policy.evaluate_all(query.definition.policies, query, context),
         {:ok, query, context} <-
           Lifecycle.run_before_dispatch(query.definition.lifecycle, query, context),
         {:ok, result} <- dispatch_query(route, query, opts),
         {:ok, final_result} <-
           Lifecycle.run_after_dispatch(query.definition.lifecycle, query, result, context) do
      {:ok, final_result}
    else
      {:error, %Error{} = error} ->
        Telemetry.maybe_emit_adapter_error(query, error)
        Lifecycle.notify_after_error(query.definition.lifecycle, query, error, query.context)
        {:error, error}
    end
  end

  defp do_route(%Admin{} = admin, opts) do
    with {:ok, route} <- resolve(admin),
         {:ok, admin, context} <-
           Lifecycle.run_before_validation(admin.definition.lifecycle, admin, admin.context),
         :ok <- Policy.evaluate_all(admin.definition.policies, admin, context),
         {:ok, admin, context} <-
           Lifecycle.run_before_dispatch(admin.definition.lifecycle, admin, context),
         :ok <- Telemetry.admin_maintenance(admin),
         {:ok, result} <- dispatch_admin(route, admin, opts),
         {:ok, final_result} <-
           Lifecycle.run_after_dispatch(admin.definition.lifecycle, admin, result, context) do
      {:ok, final_result}
    else
      {:error, %Error{} = error} ->
        Telemetry.maybe_emit_adapter_error(admin, error)
        Lifecycle.notify_after_error(admin.definition.lifecycle, admin, error, admin.context)
        {:error, error}
    end
  end

  defp do_route(request, _opts) do
    {:error,
     Error.validation(
       :invalid_request,
       "Domain route expects a command, query, or admin request",
       field: :request,
       actual: inspect(request)
     )}
  end

  defp dispatch_command(
         %Route.Definition{dispatch_via: :kernel_runtime, operation: operation},
         %Command{} = command,
         opts
       ) do
    case Keyword.get(opts, :kernel_runtime) do
      nil ->
        {:error,
         Error.not_configured(:kernel_runtime,
           operation: {:command, operation},
           route: command.route.name
         )}

      runtime ->
        dispatch_port(
          runtime,
          :dispatch_command,
          command,
          {:command, operation},
          command.route.name,
          :kernel_runtime
        )
    end
  end

  defp dispatch_command(
         %Route.Definition{dispatch_via: :external_integration, operation: operation},
         %Command{} = command,
         opts
       ) do
    case Keyword.get(opts, :external_integration) do
      nil ->
        {:error,
         Error.not_configured(:external_integration,
           operation: {:command, operation},
           route: command.route.name
         )}

      integration ->
        dispatch_port(
          integration,
          :dispatch_command,
          command,
          {:command, operation},
          command.route.name,
          :external_integration
        )
    end
  end

  defp dispatch_query(
         %Route.Definition{dispatch_via: :kernel_runtime, operation: operation},
         %Query{} = query,
         opts
       ) do
    case Keyword.get(opts, :kernel_runtime) do
      nil ->
        {:error,
         Error.not_configured(:kernel_runtime,
           operation: {:query, operation},
           route: query.route.name
         )}

      runtime ->
        dispatch_port(
          runtime,
          :run_query,
          query,
          {:query, operation},
          query.route.name,
          :kernel_runtime
        )
    end
  end

  defp dispatch_query(
         %Route.Definition{dispatch_via: :external_integration, operation: operation},
         %Query{} = query,
         opts
       ) do
    case Keyword.get(opts, :external_integration) do
      nil ->
        {:error,
         Error.not_configured(:external_integration,
           operation: {:query, operation},
           route: query.route.name
         )}

      integration ->
        dispatch_port(
          integration,
          :run_query,
          query,
          {:query, operation},
          query.route.name,
          :external_integration
        )
    end
  end

  defp dispatch_admin(
         %Route.Definition{dispatch_via: :kernel_runtime, operation: operation},
         %Admin{} = admin,
         opts
       ) do
    case Keyword.get(opts, :kernel_runtime) do
      nil ->
        {:error,
         Error.not_configured(:kernel_runtime,
           operation: {:admin, operation},
           route: admin.route.name
         )}

      runtime ->
        dispatch_port(
          runtime,
          :dispatch_command,
          admin,
          {:admin, operation},
          admin.route.name,
          :kernel_runtime
        )
    end
  end

  defp dispatch_admin(
         %Route.Definition{dispatch_via: :external_integration, operation: operation},
         %Admin{} = admin,
         opts
       ) do
    case Keyword.get(opts, :external_integration) do
      nil ->
        {:error,
         Error.not_configured(:external_integration,
           operation: {:admin, operation},
           route: admin.route.name
         )}

      integration ->
        dispatch_port(
          integration,
          :dispatch_command,
          admin,
          {:admin, operation},
          admin.route.name,
          :external_integration
        )
    end
  end

  defp dispatch_port(port_ref, callback, request, operation, route_name, component) do
    with {:ok, runtime, runtime_opts} <- normalize_port_ref(port_ref, component) do
      cond do
        exports_callback?(runtime, callback, 2) ->
          apply(runtime, callback, [request, runtime_opts])

        exports_callback?(runtime, callback, 1) ->
          apply(runtime, callback, [request])

        true ->
          {:error, Error.not_configured(component, operation: operation, route: route_name)}
      end
    end
  end

  defp normalize_port_ref({runtime, runtime_opts}, _component)
       when is_atom(runtime) and is_list(runtime_opts) do
    {:ok, runtime, runtime_opts}
  end

  defp normalize_port_ref(runtime, _component) when is_atom(runtime) do
    {:ok, runtime, []}
  end

  defp normalize_port_ref(_runtime_ref, component) do
    {:error, Error.not_configured(component)}
  end

  defp exports_callback?(runtime, callback, arity) when is_atom(runtime) do
    Code.ensure_loaded?(runtime) and function_exported?(runtime, callback, arity)
  end
end
