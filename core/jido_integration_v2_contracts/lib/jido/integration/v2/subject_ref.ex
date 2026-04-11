defmodule Jido.Integration.V2.SubjectRef do
  @moduledoc """
  Stable reference to the primary node-local subject a higher-order record is about.
  """

  alias Jido.Integration.V2.Support

  @kinds [
    :run,
    :attempt,
    :event,
    :artifact,
    :trigger,
    :capability,
    :target,
    :connection,
    :install
  ]

  @type kind ::
          :run
          | :attempt
          | :event
          | :artifact
          | :trigger
          | :capability
          | :target
          | :connection
          | :install

  @type t :: %__MODULE__{
          ref: String.t(),
          kind: kind(),
          id: String.t(),
          metadata: map()
        }

  @enforce_keys [:kind, :id]
  defstruct ref: nil, kind: nil, id: nil, metadata: %{}

  @spec new(map() | keyword() | t()) :: {:ok, t()} | {:error, Exception.t()}
  def new(%__MODULE__{} = subject_ref), do: normalize(subject_ref)

  def new(attrs) do
    Support.wrap_new(__MODULE__, fn ->
      attrs = Support.attrs!(attrs, __MODULE__)

      %__MODULE__{
        ref: Support.fetch(attrs, :ref),
        kind:
          Support.enum!(
            Support.fetch!(attrs, :kind, "subject_ref.kind"),
            @kinds,
            "subject_ref.kind"
          ),
        id:
          Support.non_empty_string!(
            Support.fetch!(attrs, :id, "subject_ref.id"),
            "subject_ref.id"
          ),
        metadata: Support.map!(Support.fetch(attrs, :metadata) || %{}, "subject_ref.metadata")
      }
      |> normalize!()
    end)
  end

  @spec new!(map() | keyword() | t()) :: t()
  def new!(%__MODULE__{} = subject_ref), do: normalize(subject_ref) |> Support.unwrap_new!()
  def new!(attrs), do: new(attrs) |> Support.unwrap_new!()

  @spec ref(kind(), String.t()) :: String.t()
  def ref(kind, id), do: Support.reference_uri("subject", kind, id)

  @spec dump(t()) :: %{ref: String.t(), kind: kind(), id: String.t(), metadata: map()}
  def dump(%__MODULE__{} = subject_ref) do
    %{
      ref: subject_ref.ref,
      kind: subject_ref.kind,
      id: subject_ref.id,
      metadata: subject_ref.metadata
    }
  end

  defp normalize(%__MODULE__{} = subject_ref) do
    Support.wrap_new(__MODULE__, fn -> normalize!(subject_ref) end)
  end

  defp normalize!(%__MODULE__{} = subject_ref) do
    expected_ref = ref(subject_ref.kind, subject_ref.id)

    if is_nil(subject_ref.ref) or subject_ref.ref == expected_ref do
      %__MODULE__{
        subject_ref
        | ref: expected_ref,
          metadata: Support.map!(subject_ref.metadata, "subject_ref.metadata")
      }
    else
      raise ArgumentError,
            "subject_ref.ref must match kind and id: #{inspect({subject_ref.kind, subject_ref.id, subject_ref.ref})}"
    end
  end
end
