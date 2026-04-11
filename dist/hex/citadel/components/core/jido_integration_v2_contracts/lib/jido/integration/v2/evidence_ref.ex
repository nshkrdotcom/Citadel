defmodule Jido.Integration.V2.EvidenceRef do
  @moduledoc """
  Stable reference to a source record backing a packet, decision, or interpretation.
  """

  alias Jido.Integration.V2.SubjectRef
  alias Jido.Integration.V2.Support

  @kinds [:run, :attempt, :event, :artifact, :trigger, :target, :connection, :install]

  @type kind :: :run | :attempt | :event | :artifact | :trigger | :target | :connection | :install

  @type t :: %__MODULE__{
          ref: String.t(),
          kind: kind(),
          id: String.t(),
          packet_ref: String.t(),
          subject: SubjectRef.t(),
          metadata: map()
        }

  @enforce_keys [:kind, :id, :packet_ref, :subject]
  defstruct ref: nil, kind: nil, id: nil, packet_ref: nil, subject: nil, metadata: %{}

  @spec new(map() | keyword() | t()) :: {:ok, t()} | {:error, Exception.t()}
  def new(%__MODULE__{} = evidence_ref), do: normalize(evidence_ref)

  def new(attrs) do
    Support.wrap_new(__MODULE__, fn ->
      attrs = Support.attrs!(attrs, __MODULE__)

      %__MODULE__{
        ref: Support.fetch(attrs, :ref),
        kind:
          Support.enum!(
            Support.fetch!(attrs, :kind, "evidence_ref.kind"),
            @kinds,
            "evidence_ref.kind"
          ),
        id:
          Support.non_empty_string!(
            Support.fetch!(attrs, :id, "evidence_ref.id"),
            "evidence_ref.id"
          ),
        packet_ref:
          Support.non_empty_string!(
            Support.fetch!(attrs, :packet_ref, "evidence_ref.packet_ref"),
            "evidence_ref.packet_ref"
          ),
        subject:
          Support.struct!(
            Support.fetch!(attrs, :subject, "evidence_ref.subject"),
            SubjectRef,
            "evidence_ref.subject"
          ),
        metadata: Support.map!(Support.fetch(attrs, :metadata) || %{}, "evidence_ref.metadata")
      }
      |> normalize!()
    end)
  end

  @spec new!(map() | keyword() | t()) :: t()
  def new!(%__MODULE__{} = evidence_ref), do: normalize(evidence_ref) |> Support.unwrap_new!()
  def new!(attrs), do: new(attrs) |> Support.unwrap_new!()

  @spec ref(kind(), String.t()) :: String.t()
  def ref(kind, id), do: Support.reference_uri("evidence", kind, id)

  @spec dump(t()) :: %{
          ref: String.t(),
          kind: kind(),
          id: String.t(),
          packet_ref: String.t(),
          subject: map(),
          metadata: map()
        }
  def dump(%__MODULE__{} = evidence_ref) do
    %{
      ref: evidence_ref.ref,
      kind: evidence_ref.kind,
      id: evidence_ref.id,
      packet_ref: evidence_ref.packet_ref,
      subject: SubjectRef.dump(evidence_ref.subject),
      metadata: evidence_ref.metadata
    }
  end

  defp normalize(%__MODULE__{} = evidence_ref) do
    Support.wrap_new(__MODULE__, fn -> normalize!(evidence_ref) end)
  end

  defp normalize!(%__MODULE__{} = evidence_ref) do
    expected_ref = ref(evidence_ref.kind, evidence_ref.id)

    if is_nil(evidence_ref.ref) or evidence_ref.ref == expected_ref do
      %__MODULE__{
        evidence_ref
        | ref: expected_ref,
          packet_ref:
            Support.non_empty_string!(evidence_ref.packet_ref, "evidence_ref.packet_ref"),
          metadata: Support.map!(evidence_ref.metadata, "evidence_ref.metadata")
      }
    else
      raise ArgumentError,
            "evidence_ref.ref must match kind and id: #{inspect({evidence_ref.kind, evidence_ref.id, evidence_ref.ref})}"
    end
  end
end
