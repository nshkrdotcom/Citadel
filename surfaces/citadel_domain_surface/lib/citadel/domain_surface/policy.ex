defmodule Citadel.DomainSurface.Policy do
  @moduledoc """
  Explicit Domain policy helper declaration.

  Policy helpers remain ordinary modules. They evaluate requests directly and
  return `:ok` or a Domain error without hiding mutable coordinator state.
  """

  alias Citadel.DomainSurface.{Error, Support}

  defmodule Definition do
    @moduledoc """
    Internal policy definition struct used by the public policy API.
    """

    @enforce_keys [:name]
    defstruct [:module, :name, :description, mode: :enforced, metadata: %{}]

    @type mode :: :enforced | :advisory

    @type t :: %__MODULE__{
            name: atom(),
            description: String.t() | nil,
            mode: mode(),
            metadata: map()
          }
  end

  @type source :: module() | Definition.t()
  @type context :: map() | nil

  @callback definition() :: Definition.t()
  @callback evaluate(term(), context()) :: :ok | {:error, Error.t()}

  @spec definition!(map() | keyword()) :: Definition.t()
  def definition!(attrs) do
    attrs = Map.new(attrs)

    %Definition{
      module: nil,
      name: required_atom!(attrs, :name),
      description: optional_string(Map.get(attrs, :description)),
      mode: mode!(Map.get(attrs, :mode, :enforced)),
      metadata: metadata!(Map.get(attrs, :metadata, %{}))
    }
  end

  @spec fetch_definition(source()) :: {:ok, Definition.t()} | {:error, Error.t()}
  def fetch_definition(source), do: Support.fetch_definition(source, Definition, :policy)

  @spec evaluate_all([source()], term(), context()) :: :ok | {:error, Error.t()}
  def evaluate_all(policies, request, context) do
    Enum.reduce_while(policies, :ok, fn policy, :ok ->
      evaluate_policy(policy, request, context)
    end)
  end

  defp evaluate_policy(policy, request, context) do
    case fetch_definition(policy) do
      {:ok, definition} -> evaluate_policy_module(policy, definition, request, context)
      {:error, _error} = error -> {:halt, error}
    end
  end

  defp evaluate_policy_module(policy, definition, request, context) do
    case callback_module(policy, definition) do
      {:ok, module} -> run_policy_evaluation(policy, module, request, context)
      {:error, _error} = error -> {:halt, error}
    end
  end

  defp run_policy_evaluation(policy, module, request, context) do
    if function_exported?(module, :evaluate, 2) do
      case module.evaluate(request, context) do
        :ok -> {:cont, :ok}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
        other -> {:halt, {:error, invalid_policy_result(policy, other)}}
      end
    else
      {:halt, {:error, invalid_policy_result(policy, :missing_evaluate_callback)}}
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
       "policy #{inspect(source)} must come from a module when it is evaluated",
       definition_kind: :policy
     )}
  end

  defp invalid_policy_result(policy, result) do
    Error.validation(
      :invalid_definition,
      "policy #{inspect(policy)} returned #{inspect(result)} instead of :ok or {:error, %Citadel.DomainSurface.Error{}}",
      definition_kind: :policy
    )
  end

  defp required_atom!(attrs, key) do
    case Map.get(attrs, key) do
      value when is_atom(value) -> value
      value -> raise ArgumentError, "policy #{key} must be an atom, got: #{inspect(value)}"
    end
  end

  defp optional_string(nil), do: nil
  defp optional_string(value) when is_binary(value), do: String.trim(value)

  defp optional_string(value),
    do: raise(ArgumentError, "policy description must be a string, got: #{inspect(value)}")

  defp mode!(:enforced), do: :enforced
  defp mode!(:advisory), do: :advisory

  defp mode!(value),
    do: raise(ArgumentError, "policy mode must be :enforced or :advisory, got: #{inspect(value)}")

  defp metadata!(value) do
    case Support.normalize_metadata(value) do
      {:ok, metadata} -> metadata
      {:error, error} -> raise ArgumentError, error.message
    end
  end
end
