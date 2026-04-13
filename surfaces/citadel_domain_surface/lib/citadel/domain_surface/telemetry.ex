defmodule Citadel.DomainSurface.Telemetry do
  @moduledoc """
  Frozen low-cardinality telemetry contract for packet-critical Domain seams.

  Canonical events are emitted through `:telemetry.execute/3`:

  - `[:citadel_domain_surface, :command, :submit]`
  - `[:citadel_domain_surface, :command, :rejected]`
  - `[:citadel_domain_surface, :command, :idempotency]`
  - `[:citadel_domain_surface, :adapter, :failure]`
  - `[:citadel_domain_surface, :adapter, :circuit_open]`
  - `[:citadel_domain_surface, :admin, :maintenance]`

  Measurements stay backend-neutral and bounded with `%{count: 1}`.
  Metadata is intentionally classification-oriented and excludes payload values,
  trace ids, idempotency keys, and operator-entered free text.
  """

  alias Citadel.DomainSurface.Adapters.CitadelAdapter.Accepted
  alias Citadel.DomainSurface.{Admin, Command, Error, Query}

  @type request :: Command.t() | Query.t() | Admin.t()
  @type event_key ::
          :adapter_circuit_open
          | :adapter_failure
          | :admin_maintenance
          | :command_idempotency
          | :command_rejected
          | :command_submit

  @contract %{
    command_submit: %{
      event_name: [:citadel_domain_surface, :command, :submit],
      measurements: [:count],
      metadata: [:request_name, :dispatch_via]
    },
    command_rejected: %{
      event_name: [:citadel_domain_surface, :command, :rejected],
      measurements: [:count],
      metadata: [
        :request_name,
        :dispatch_via,
        :rejection_code,
        :rejection_stage,
        :reason_code,
        :retryability,
        :publication
      ]
    },
    command_idempotency: %{
      event_name: [:citadel_domain_surface, :command, :idempotency],
      measurements: [:count],
      metadata: [:request_name, :dispatch_via, :classification]
    },
    adapter_failure: %{
      event_name: [:citadel_domain_surface, :adapter, :failure],
      measurements: [:count],
      metadata: [:request_type, :request_name, :dispatch_via, :component, :failure_class]
    },
    adapter_circuit_open: %{
      event_name: [:citadel_domain_surface, :adapter, :circuit_open],
      measurements: [:count],
      metadata: [:request_type, :request_name, :dispatch_via, :component, :failure_class]
    },
    admin_maintenance: %{
      event_name: [:citadel_domain_surface, :admin, :maintenance],
      measurements: [:count],
      metadata: [:admin_name, :dispatch_via, :operation, :auditable?]
    }
  }

  @known_failure_classes [
    :ambiguous_submit,
    :circuit_open,
    :connection_dropped,
    :not_configured,
    :submission_inflight,
    :timeout
  ]

  @known_components [
    :citadel_adapter,
    :external_integration,
    :id_port,
    :kernel_runtime,
    :maintenance_surface,
    :query_surface,
    :request_submission
  ]

  @spec contract() :: %{required(event_key()) => map()}
  def contract, do: @contract

  @spec event_name(event_key()) :: [atom(), ...]
  def event_name(key), do: @contract |> Map.fetch!(key) |> Map.fetch!(:event_name)

  @spec command_submit(Command.t()) :: :ok
  def command_submit(%Command{} = command) do
    emit(:command_submit, %{count: 1}, %{
      request_name: command.name,
      dispatch_via: command.route.dispatch_via
    })
  end

  @spec maybe_emit_command_rejection(Command.t(), Error.t()) :: :ok
  def maybe_emit_command_rejection(%Command{} = command, %Error{category: :rejected} = error) do
    emit(:command_rejected, %{count: 1}, %{
      request_name: command.name,
      dispatch_via: command.route.dispatch_via,
      rejection_code: error.code,
      rejection_stage: rejection_stage(error),
      reason_code: rejection_reason_code(error),
      retryability: error.retryability || :unknown,
      publication: error.publication || :unknown
    })
  end

  def maybe_emit_command_rejection(%Command{}, %Error{}), do: :ok

  @spec maybe_emit_command_idempotency(Command.t(), term()) :: :ok
  def maybe_emit_command_idempotency(%Command{} = command, %Accepted{} = accepted) do
    case Map.get(accepted.metadata, :deduplicated?) do
      true ->
        emit(:command_idempotency, %{count: 1}, %{
          request_name: command.name,
          dispatch_via: command.route.dispatch_via,
          classification: :hit
        })

      false ->
        emit(:command_idempotency, %{count: 1}, %{
          request_name: command.name,
          dispatch_via: command.route.dispatch_via,
          classification: :miss
        })

      _other ->
        :ok
    end
  end

  def maybe_emit_command_idempotency(%Command{}, _result), do: :ok

  @spec admin_maintenance(Admin.t()) :: :ok
  def admin_maintenance(%Admin{} = admin) do
    emit(:admin_maintenance, %{count: 1}, %{
      admin_name: admin.name,
      dispatch_via: admin.route.dispatch_via,
      operation: admin.route.operation,
      auditable?: admin.definition.auditable?
    })
  end

  @spec maybe_emit_adapter_error(request(), Error.t()) :: :ok
  def maybe_emit_adapter_error(request, %Error{} = error) do
    case adapter_event(error) do
      {:ok, event_key, metadata} ->
        emit(event_key, %{count: 1}, Map.merge(request_metadata(request), metadata))

      :ignore ->
        :ok
    end
  end

  defp emit(key, measurements, metadata) do
    :telemetry.execute(event_name(key), measurements, metadata)
  end

  defp adapter_event(%Error{
         category: :configuration,
         code: :not_configured,
         details: %{component: component, reason: reason}
       }) do
    failure_class = failure_class(reason)
    component = component_class(component)

    event_key =
      if failure_class == :circuit_open, do: :adapter_circuit_open, else: :adapter_failure

    {:ok, event_key, %{component: component, failure_class: failure_class}}
  end

  defp adapter_event(%Error{}), do: :ignore

  defp request_metadata(%Command{} = command) do
    %{
      request_type: :command,
      request_name: command.name,
      dispatch_via: command.route.dispatch_via
    }
  end

  defp request_metadata(%Query{} = query) do
    %{
      request_type: :query,
      request_name: query.name,
      dispatch_via: query.route.dispatch_via
    }
  end

  defp request_metadata(%Admin{} = admin) do
    %{
      request_type: :admin,
      request_name: admin.name,
      dispatch_via: admin.route.dispatch_via
    }
  end

  defp rejection_stage(%Error{source: %{stage: stage}}) when is_atom(stage), do: stage
  defp rejection_stage(%Error{details: %{stage: stage}}) when is_atom(stage), do: stage
  defp rejection_stage(_error), do: :unknown

  defp rejection_reason_code(%Error{details: %{reason_code: reason_code}})
       when is_binary(reason_code) and reason_code != "",
       do: reason_code

  defp rejection_reason_code(%Error{source: %{reason_code: reason_code}})
       when is_binary(reason_code) and reason_code != "",
       do: reason_code

  defp rejection_reason_code(_error), do: "unknown"

  defp failure_class(reason) when is_atom(reason) and reason in @known_failure_classes, do: reason

  defp failure_class(reason) when is_binary(reason) do
    case Enum.find(@known_failure_classes, &(Atom.to_string(&1) == reason)) do
      nil -> :other
      failure_class -> failure_class
    end
  end

  defp failure_class(_reason), do: :other

  defp component_class(component) when is_atom(component) and component in @known_components,
    do: component

  defp component_class(component) when is_binary(component) do
    case Enum.find(@known_components, &(Atom.to_string(&1) == component)) do
      nil -> :other
      known_component -> known_component
    end
  end

  defp component_class(_component), do: :other
end
