defmodule Citadel.DomainSurface.Command do
  @moduledoc """
  Host-facing semantic command declaration and boundary request.

  Domain authors use ordinary modules with `definition/0` to declare commands.
  Host code builds commands through `new/3` or the higher-level
  `Citadel.DomainSurface.command/3` entry point.
  """

  alias Citadel.DomainSurface.{Artifact, Error, Lifecycle, Policy, Route, Support}

  @type input :: Citadel.DomainSurface.payload()
  @type metadata :: Citadel.DomainSurface.metadata()
  @type context :: %{optional(atom() | String.t()) => term()} | struct() | nil
  @type definition_attrs :: keyword() | %{optional(atom() | String.t()) => term()}

  defmodule Definition do
    @moduledoc """
    Internal command definition struct used by the public command API.
    """

    @enforce_keys [:name, :route]
    defstruct [
      :module,
      :name,
      :route,
      :description,
      lifecycle: [],
      policies: [],
      artifacts: [],
      metadata: %{}
    ]

    @type t :: %__MODULE__{
            name: atom(),
            route: Route.source(),
            description: String.t() | nil,
            lifecycle: [Lifecycle.source()],
            policies: [Policy.source()],
            artifacts: [Artifact.source()],
            metadata: Citadel.DomainSurface.Command.metadata()
          }
  end

  @type t :: %__MODULE__{
          definition: Definition.t(),
          route: Route.t(),
          name: atom(),
          input: input(),
          idempotency_key: Citadel.DomainSurface.idempotency_key(),
          trace_id: Citadel.DomainSurface.trace_id() | nil,
          metadata: metadata(),
          context: context()
        }

  @type source :: module() | Definition.t()

  @enforce_keys [:definition, :route, :name, :input, :idempotency_key]
  defstruct [
    :definition,
    :route,
    :name,
    :input,
    :idempotency_key,
    :trace_id,
    metadata: %{},
    context: nil
  ]

  @callback definition() :: Definition.t()

  @spec definition!(definition_attrs()) :: Definition.t()
  def definition!(attrs) do
    attrs = Map.new(attrs)

    %Definition{
      module: nil,
      name: required_atom!(attrs, :name, "command"),
      route: Map.fetch!(attrs, :route),
      description: optional_string(Map.get(attrs, :description)),
      lifecycle: refs!(Map.get(attrs, :lifecycle, []), :lifecycle),
      policies: refs!(Map.get(attrs, :policies, []), :policy),
      artifacts: refs!(Map.get(attrs, :artifacts, []), :artifact),
      metadata: metadata!(Map.get(attrs, :metadata, %{}))
    }
  end

  @spec fetch_definition(source()) :: {:ok, Definition.t()} | {:error, Error.t()}
  def fetch_definition(source), do: Support.fetch_definition(source, Definition, :command)

  @spec new(source(), input(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def new(commandable, input, opts \\ []) do
    with {:ok, opts} <- Support.normalize_options(opts),
         {:ok, definition} <- fetch_definition(commandable),
         :ok <- validate_refs(definition),
         {:ok, route} <-
           Route.validate_definition(definition.route, :command, command: definition.name),
         {:ok, idempotency_key} <- require_idempotency_key(definition.name, opts),
         {:ok, metadata} <-
           Support.normalize_metadata(Keyword.get(opts, :metadata, definition.metadata)),
         {:ok, context} <- Support.normalize_context(Keyword.get(opts, :context)),
         {:ok, trace_id} <- Support.resolve_trace_id(opts, context) do
      {:ok,
       %__MODULE__{
         definition: definition,
         route: route,
         name: definition.name,
         input: input,
         idempotency_key: idempotency_key,
         trace_id: trace_id,
         metadata: metadata,
         context: context
       }}
    end
  end

  @spec new!(source(), input(), keyword()) :: t()
  def new!(commandable, input, opts \\ []) do
    case new(commandable, input, opts) do
      {:ok, command} -> command
      {:error, error} -> raise ArgumentError, error.message
    end
  end

  defp validate_refs(%Definition{} = definition) do
    case validate_definition_refs(definition.lifecycle, &Lifecycle.fetch_definition/1) do
      :ok ->
        case validate_definition_refs(definition.policies, &Policy.fetch_definition/1) do
          :ok -> validate_definition_refs(definition.artifacts, &Artifact.fetch_definition/1)
          {:error, _error} = error -> error
        end

      {:error, _error} = error ->
        error
    end
  end

  defp validate_definition_refs(refs, fetcher) do
    Enum.reduce_while(refs, :ok, fn ref, :ok ->
      case fetcher.(ref) do
        {:ok, _definition} -> {:cont, :ok}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp require_idempotency_key(command_name, opts) do
    case Support.normalize_optional_string(Keyword.get(opts, :idempotency_key), :idempotency_key) do
      {:ok, nil} -> {:error, Error.missing_idempotency_key(command_name)}
      {:ok, value} -> {:ok, value}
      {:error, _error} -> {:error, Error.missing_idempotency_key(command_name)}
    end
  end

  defp required_atom!(attrs, key, label) do
    case Map.get(attrs, key) do
      value when is_atom(value) -> value
      value -> raise ArgumentError, "#{label} #{key} must be an atom, got: #{inspect(value)}"
    end
  end

  defp refs!(value, _kind) when is_list(value), do: value

  defp refs!(value, kind) do
    raise ArgumentError, "#{kind} references must be a list, got: #{inspect(value)}"
  end

  defp optional_string(nil), do: nil
  defp optional_string(value) when is_binary(value), do: String.trim(value)

  defp optional_string(value),
    do: raise(ArgumentError, "command description must be a string, got: #{inspect(value)}")

  defp metadata!(value) do
    case Support.normalize_metadata(value) do
      {:ok, metadata} -> metadata
      {:error, error} -> raise ArgumentError, error.message
    end
  end
end
