defmodule Citadel.DomainSurface.Lifecycle do
  @moduledoc """
  Explicit lifecycle hook declaration for Domain requests.

  Hooks stay ordinary modules and ordinary functions. Domain does not synthesize
  hidden coordinators or in-memory state machines around them.
  """

  alias Citadel.DomainSurface.{Error, Support}

  defmodule Definition do
    @moduledoc """
    Internal lifecycle definition struct used by the public lifecycle API.
    """

    @enforce_keys [:name, :stages]
    defstruct [:module, :name, :description, stages: [], metadata: %{}]

    @type stage :: :before_validation | :before_dispatch | :after_dispatch | :after_error

    @type t :: %__MODULE__{
            name: atom(),
            description: String.t() | nil,
            stages: [stage()],
            metadata: map()
          }
  end

  @type t :: Definition.t()
  @type source :: module() | Definition.t()
  @type context :: map() | nil

  @callback definition() :: Definition.t()
  @callback before_validation(term(), context()) :: {:ok, term(), context()} | {:error, Error.t()}
  @callback before_dispatch(term(), context()) :: {:ok, term(), context()} | {:error, Error.t()}
  @callback after_dispatch(term(), term(), context()) :: {:ok, term()} | {:error, Error.t()}
  @callback after_error(term(), Error.t(), context()) :: :ok | {:ok, Error.t()}

  @optional_callbacks before_validation: 2, before_dispatch: 2, after_dispatch: 3, after_error: 3

  @spec definition!(map() | keyword()) :: Definition.t()
  def definition!(attrs) do
    attrs = Map.new(attrs)

    %Definition{
      module: nil,
      name: required_atom!(attrs, :name),
      description: optional_string(Map.get(attrs, :description)),
      stages: stages!(Map.get(attrs, :stages, [])),
      metadata: metadata!(Map.get(attrs, :metadata, %{}))
    }
  end

  @spec fetch_definition(source()) :: {:ok, Definition.t()} | {:error, Error.t()}
  def fetch_definition(source), do: Support.fetch_definition(source, Definition, :lifecycle)

  @spec run_before_validation([source()], term(), context()) ::
          {:ok, term(), context()} | {:error, Error.t()}
  def run_before_validation(hooks, request, context),
    do: run_stage(hooks, :before_validation, request, context)

  @spec run_before_dispatch([source()], term(), context()) ::
          {:ok, term(), context()} | {:error, Error.t()}
  def run_before_dispatch(hooks, request, context),
    do: run_stage(hooks, :before_dispatch, request, context)

  @spec run_after_dispatch([source()], term(), term(), context()) ::
          {:ok, term()} | {:error, Error.t()}
  def run_after_dispatch(hooks, request, result, context) do
    Enum.reduce_while(hooks, {:ok, result}, fn hook, {:ok, current_result} ->
      run_after_dispatch_hook(hook, request, current_result, context)
    end)
  end

  @spec notify_after_error([source()], term(), Error.t(), context()) :: :ok
  def notify_after_error(hooks, request, error, context) do
    Enum.each(hooks, fn hook ->
      notify_after_error_hook(hook, request, error, context)
    end)

    :ok
  end

  defp run_stage(hooks, stage, request, context) do
    Enum.reduce_while(hooks, {:ok, request, context}, fn hook,
                                                         {:ok, current_request, current_context} ->
      run_stage_hook(hook, stage, current_request, current_context)
    end)
  end

  defp run_after_dispatch_hook(hook, request, current_result, context) do
    case fetch_definition(hook) do
      {:ok, definition} ->
        run_after_dispatch_module(hook, definition, request, current_result, context)

      {:error, _error} = error ->
        {:halt, error}
    end
  end

  defp run_after_dispatch_module(hook, definition, request, current_result, context) do
    case callback_module(hook, definition) do
      {:ok, module} -> maybe_run_after_dispatch(module, request, current_result, context)
      {:error, _error} = error -> {:halt, error}
    end
  end

  defp maybe_run_after_dispatch(module, request, current_result, context) do
    if function_exported?(module, :after_dispatch, 3) do
      case module.after_dispatch(request, current_result, context) do
        {:ok, next_result} -> {:cont, {:ok, next_result}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    else
      {:cont, {:ok, current_result}}
    end
  end

  defp notify_after_error_hook(hook, request, error, context) do
    case fetch_definition(hook) do
      {:ok, definition} -> notify_after_error_module(hook, definition, request, error, context)
      {:error, _error} -> :ok
    end
  end

  defp notify_after_error_module(hook, definition, request, error, context) do
    case callback_module(hook, definition) do
      {:ok, module} ->
        if function_exported?(module, :after_error, 3) do
          _ = module.after_error(request, error, context)
        end

      {:error, _error} ->
        :ok
    end
  end

  defp run_stage_hook(hook, stage, current_request, current_context) do
    case fetch_definition(hook) do
      {:ok, definition} ->
        run_stage_module(hook, definition, stage, current_request, current_context)

      {:error, _error} = error ->
        {:halt, error}
    end
  end

  defp run_stage_module(hook, definition, stage, current_request, current_context) do
    case callback_module(hook, definition) do
      {:ok, module} -> maybe_run_stage(module, stage, current_request, current_context)
      {:error, _error} = error -> {:halt, error}
    end
  end

  defp maybe_run_stage(module, stage, current_request, current_context) do
    if function_exported?(module, stage, 2) do
      case apply(module, stage, [current_request, current_context]) do
        {:ok, next_request, next_context} -> {:cont, {:ok, next_request, next_context}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    else
      {:cont, {:ok, current_request, current_context}}
    end
  end

  defp callback_module(source, %Definition{module: _module}) when is_atom(source),
    do: {:ok, source}

  defp callback_module(_source, %Definition{module: module}) when is_atom(module),
    do: {:ok, module}

  defp callback_module(source, _definition) do
    {:error,
     Error.validation(
       :invalid_definition,
       "lifecycle hook #{inspect(source)} must come from a module when it is executed",
       definition_kind: :lifecycle
     )}
  end

  defp required_atom!(attrs, key) do
    case Map.get(attrs, key) do
      value when is_atom(value) -> value
      value -> raise ArgumentError, "lifecycle #{key} must be an atom, got: #{inspect(value)}"
    end
  end

  defp optional_string(nil), do: nil
  defp optional_string(value) when is_binary(value), do: String.trim(value)

  defp optional_string(value) do
    raise ArgumentError, "lifecycle description must be a string, got: #{inspect(value)}"
  end

  defp stages!(stages) when is_list(stages) do
    stages
    |> Enum.map(&stage!/1)
    |> Enum.uniq()
  end

  defp stages!(value) do
    raise ArgumentError, "lifecycle stages must be a list, got: #{inspect(value)}"
  end

  defp stage!(:before_validation), do: :before_validation
  defp stage!(:before_dispatch), do: :before_dispatch
  defp stage!(:after_dispatch), do: :after_dispatch
  defp stage!(:after_error), do: :after_error

  defp stage!(value) do
    raise ArgumentError,
          "lifecycle stage must be :before_validation, :before_dispatch, :after_dispatch, or :after_error, got: #{inspect(value)}"
  end

  defp metadata!(value) do
    case Support.normalize_metadata(value) do
      {:ok, metadata} -> metadata
      {:error, error} -> raise ArgumentError, error.message
    end
  end
end
