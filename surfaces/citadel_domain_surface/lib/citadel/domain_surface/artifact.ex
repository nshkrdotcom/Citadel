defmodule Citadel.DomainSurface.Artifact do
  @moduledoc """
  Host-facing artifact declaration and artifact value.

  Artifacts and projections are shaped explicitly above Citadel. They remain
  plain data plus ordinary builder functions.
  """

  alias Citadel.DomainSurface.{Error, Support}

  defmodule Definition do
    @moduledoc """
    Internal artifact definition struct used by the public artifact API.
    """

    @enforce_keys [:name, :kind]
    defstruct [:module, :name, :kind, :description, metadata: %{}]

    @type t :: %__MODULE__{
            name: atom(),
            kind: atom(),
            description: String.t() | nil,
            metadata: map()
          }
  end

  @type source :: module() | Definition.t()

  @type t :: %__MODULE__{
          definition: Definition.t(),
          name: atom(),
          kind: atom(),
          body: term(),
          metadata: map()
        }

  @enforce_keys [:definition, :name, :kind, :body]
  defstruct [:definition, :name, :kind, :body, metadata: %{}]

  @callback definition() :: Definition.t()
  @callback build(term(), keyword()) :: t()

  @optional_callbacks build: 2

  @spec definition!(map() | keyword()) :: Definition.t()
  def definition!(attrs) do
    attrs = Map.new(attrs)

    %Definition{
      module: nil,
      name: required_atom!(attrs, :name, "artifact"),
      kind: required_atom!(attrs, :kind, "artifact"),
      description: optional_string(Map.get(attrs, :description)),
      metadata: metadata!(Map.get(attrs, :metadata, %{}))
    }
  end

  @spec fetch_definition(source()) :: {:ok, Definition.t()} | {:error, Error.t()}
  def fetch_definition(source), do: Support.fetch_definition(source, Definition, :artifact)

  @spec new(source(), term(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def new(artifactable, body, opts \\ []) do
    with {:ok, definition} <- fetch_definition(artifactable),
         {:ok, metadata} <-
           Support.normalize_metadata(Keyword.get(opts, :metadata, definition.metadata)) do
      {:ok,
       %__MODULE__{
         definition: definition,
         name: definition.name,
         kind: definition.kind,
         body: body,
         metadata: metadata
       }}
    end
  end

  @spec new!(source(), term(), keyword()) :: t()
  def new!(artifactable, body, opts \\ []) do
    case new(artifactable, body, opts) do
      {:ok, artifact} -> artifact
      {:error, error} -> raise ArgumentError, error.message
    end
  end

  defp required_atom!(attrs, key, label) do
    case Map.get(attrs, key) do
      value when is_atom(value) -> value
      value -> raise ArgumentError, "#{label} #{key} must be an atom, got: #{inspect(value)}"
    end
  end

  defp optional_string(nil), do: nil
  defp optional_string(value) when is_binary(value), do: String.trim(value)

  defp optional_string(value),
    do: raise(ArgumentError, "artifact description must be a string, got: #{inspect(value)}")

  defp metadata!(value) do
    case Support.normalize_metadata(value) do
      {:ok, metadata} -> metadata
      {:error, error} -> raise ArgumentError, error.message
    end
  end
end
