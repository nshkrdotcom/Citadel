defmodule Citadel.DomainSurface.Route do
  @moduledoc """
  Explicit semantic route declaration above Citadel.

  A route names the public Domain path, the request kind it serves, the
  semantic lower operation, and the orchestration posture. Routes do not expose
  raw signal names or hidden in-memory saga behavior.
  """

  alias Citadel.DomainSurface.{Error, Orchestration, Support}

  defmodule Definition do
    @moduledoc """
    Internal route definition struct used by the public route API.
    """

    @enforce_keys [:name, :request_type, :operation, :dispatch_via, :orchestration]
    defstruct [
      :module,
      :name,
      :request_type,
      :operation,
      :dispatch_via,
      :version,
      :schema_hash,
      :description,
      :orchestration,
      metadata: %{},
      semantic_metadata: %{},
      tool_manifest: %{},
      read_descriptor: nil,
      operator_hints: %{}
    ]

    @type request_type :: :command | :query | :admin
    @type dispatch_via :: :kernel_runtime | :external_integration
    @type version :: String.t()
    @type schema_hash :: String.t() | nil
    @type semantic_metadata :: map()
    @type tool_manifest :: map()
    @type read_descriptor :: map() | nil
    @type operator_hints :: map()

    @type t :: %__MODULE__{
            name: atom(),
            request_type: request_type(),
            operation: atom(),
            dispatch_via: dispatch_via(),
            version: version(),
            schema_hash: schema_hash(),
            description: String.t() | nil,
            orchestration: Orchestration.t(),
            metadata: map(),
            semantic_metadata: semantic_metadata(),
            tool_manifest: tool_manifest(),
            read_descriptor: read_descriptor(),
            operator_hints: operator_hints()
          }
  end

  @type t :: Definition.t()
  @type source :: module() | Definition.t()

  @callback definition() :: Definition.t()

  @spec definition!(map() | keyword()) :: Definition.t()
  def definition!(attrs) do
    attrs = Map.new(attrs)

    definition = %Definition{
      module: nil,
      name: required_atom!(attrs, :name, "route"),
      request_type: request_type!(Map.get(attrs, :request_type)),
      operation: required_atom!(attrs, :operation, "route"),
      dispatch_via: dispatch_via!(Map.get(attrs, :dispatch_via, :kernel_runtime)),
      version: version!(Map.get(attrs, :version, "1")),
      schema_hash: nil,
      description: optional_string(Map.get(attrs, :description)),
      orchestration: Orchestration.define!(Map.get(attrs, :orchestration, :stateless_sync)),
      metadata: metadata!(Map.get(attrs, :metadata, %{})),
      semantic_metadata: metadata!(Map.get(attrs, :semantic_metadata, %{})),
      tool_manifest: metadata!(Map.get(attrs, :tool_manifest, %{})),
      read_descriptor: optional_metadata!(Map.get(attrs, :read_descriptor)),
      operator_hints: metadata!(Map.get(attrs, :operator_hints, %{}))
    }

    %{definition | schema_hash: schema_hash(definition)}
  end

  @spec fetch_definition(source()) :: {:ok, Definition.t()} | {:error, Error.t()}
  def fetch_definition(source), do: Support.fetch_definition(source, Definition, :route)

  @spec version(source()) :: {:ok, Definition.version()} | {:error, Error.t()}
  def version(source) do
    with {:ok, definition} <- fetch_definition(source) do
      {:ok, definition.version}
    end
  end

  @spec schema_hash(source() | Definition.t()) :: Definition.schema_hash()
  def schema_hash(%Definition{} = definition) do
    definition
    |> schema_hash_input()
    |> Support.stable_hash()
  end

  def schema_hash(source) do
    case fetch_definition(source) do
      {:ok, definition} -> schema_hash(definition)
      {:error, error} -> raise ArgumentError, error.message
    end
  end

  @spec semantic_metadata(source()) :: {:ok, Definition.semantic_metadata()} | {:error, Error.t()}
  def semantic_metadata(source) do
    with {:ok, definition} <- fetch_definition(source) do
      {:ok, definition.semantic_metadata}
    end
  end

  @spec tool_manifest(source()) :: {:ok, Definition.tool_manifest()} | {:error, Error.t()}
  def tool_manifest(source) do
    with {:ok, definition} <- fetch_definition(source) do
      {:ok, definition.tool_manifest}
    end
  end

  @spec read_descriptor(source()) :: {:ok, Definition.read_descriptor()} | {:error, Error.t()}
  def read_descriptor(source) do
    with {:ok, definition} <- fetch_definition(source) do
      {:ok, definition.read_descriptor}
    end
  end

  @spec operator_hints(source()) :: {:ok, Definition.operator_hints()} | {:error, Error.t()}
  def operator_hints(source) do
    with {:ok, definition} <- fetch_definition(source) do
      {:ok, definition.operator_hints}
    end
  end

  @spec validate_definition(source(), Definition.request_type(), keyword()) ::
          {:ok, Definition.t()} | {:error, Error.t()}
  def validate_definition(source, expected_request_type, opts \\ []) do
    with {:ok, definition} <- fetch_definition(source),
         :ok <- validate_request_type(definition, expected_request_type),
         :ok <-
           Orchestration.validate(
             definition.orchestration,
             Keyword.put(opts, :route, definition.name)
           ) do
      {:ok, definition}
    end
  end

  defp validate_request_type(%Definition{request_type: expected}, expected), do: :ok

  defp validate_request_type(%Definition{name: name, request_type: actual}, expected) do
    {:error,
     Error.validation(
       :invalid_definition,
       "route #{inspect(name)} is declared for #{inspect(actual)} requests, not #{inspect(expected)}",
       definition_kind: :route,
       expected_request_type: expected,
       actual_request_type: actual
     )}
  end

  defp required_atom!(attrs, key, label) do
    case Map.get(attrs, key) do
      value when is_atom(value) -> value
      value -> raise ArgumentError, "#{label} #{key} must be an atom, got: #{inspect(value)}"
    end
  end

  defp request_type!(:command), do: :command
  defp request_type!(:query), do: :query
  defp request_type!(:admin), do: :admin

  defp request_type!(value) do
    raise ArgumentError,
          "route request_type must be :command, :query, or :admin, got: #{inspect(value)}"
  end

  defp dispatch_via!(:kernel_runtime), do: :kernel_runtime
  defp dispatch_via!(:external_integration), do: :external_integration

  defp dispatch_via!(value) do
    raise ArgumentError,
          "route dispatch_via must be :kernel_runtime or :external_integration, got: #{inspect(value)}"
  end

  defp version!(value) when is_binary(value) do
    trimmed = String.trim(value)

    if trimmed == "" do
      raise ArgumentError, "route version must not be blank"
    else
      trimmed
    end
  end

  defp version!(value),
    do: raise(ArgumentError, "route version must be a string, got: #{inspect(value)}")

  defp optional_string(nil), do: nil
  defp optional_string(value) when is_binary(value), do: String.trim(value)

  defp optional_string(value) do
    raise ArgumentError, "route description must be a string, got: #{inspect(value)}"
  end

  defp metadata!(value) do
    case Support.normalize_metadata(value) do
      {:ok, metadata} -> metadata
      {:error, error} -> raise ArgumentError, error.message
    end
  end

  defp optional_metadata!(nil), do: nil
  defp optional_metadata!(value), do: metadata!(value)

  defp schema_hash_input(%Definition{} = definition) do
    %{
      name: definition.name,
      request_type: definition.request_type,
      operation: definition.operation,
      dispatch_via: definition.dispatch_via,
      version: definition.version,
      description: definition.description,
      orchestration: definition.orchestration,
      metadata: definition.metadata,
      semantic_metadata: definition.semantic_metadata,
      tool_manifest: definition.tool_manifest,
      read_descriptor: definition.read_descriptor,
      operator_hints: definition.operator_hints
    }
  end
end
