defmodule Jido.Integration.V2.DerivedStateAttachment do
  @moduledoc """
  Canonical attachment contract for higher-order derived state.
  """

  alias Jido.Integration.V2.EvidenceRef
  alias Jido.Integration.V2.GovernanceRef
  alias Jido.Integration.V2.SubjectRef
  alias Jido.Integration.V2.Support

  @type t :: %__MODULE__{
          subject: SubjectRef.t(),
          evidence_refs: [EvidenceRef.t()],
          governance_refs: [GovernanceRef.t()],
          metadata: map()
        }

  @type dump_t :: %{
          subject: map(),
          evidence_refs: [map()],
          governance_refs: [map()],
          metadata: map()
        }

  @enforce_keys [:subject]
  defstruct subject: nil, evidence_refs: [], governance_refs: [], metadata: %{}

  @spec new(map() | keyword() | t()) :: {:ok, t()} | {:error, Exception.t()}
  def new(%__MODULE__{} = attachment), do: normalize(attachment)

  def new(attrs) do
    Support.wrap_new(__MODULE__, fn ->
      attrs = Support.attrs!(attrs, __MODULE__)

      %__MODULE__{
        subject:
          Support.struct!(
            Support.fetch!(attrs, :subject, "derived_state_attachment.subject"),
            SubjectRef,
            "derived_state_attachment.subject"
          ),
        evidence_refs:
          Support.list!(
            Support.fetch(attrs, :evidence_refs) || [],
            "derived_state_attachment.evidence_refs",
            fn item ->
              Support.struct!(item, EvidenceRef, "derived_state_attachment.evidence_refs")
            end
          ),
        governance_refs:
          Support.list!(
            Support.fetch(attrs, :governance_refs) || [],
            "derived_state_attachment.governance_refs",
            fn item ->
              Support.struct!(item, GovernanceRef, "derived_state_attachment.governance_refs")
            end
          ),
        metadata:
          Support.map!(
            Support.fetch(attrs, :metadata) || %{},
            "derived_state_attachment.metadata"
          )
      }
      |> normalize!()
    end)
  end

  @spec new!(map() | keyword() | t()) :: t()
  def new!(%__MODULE__{} = attachment), do: normalize(attachment) |> Support.unwrap_new!()
  def new!(attrs), do: new(attrs) |> Support.unwrap_new!()

  @spec dump(t()) :: dump_t()
  def dump(%__MODULE__{} = attachment) do
    %{
      subject: SubjectRef.dump(attachment.subject),
      evidence_refs: Enum.map(attachment.evidence_refs, &EvidenceRef.dump/1),
      governance_refs: Enum.map(attachment.governance_refs, &GovernanceRef.dump/1),
      metadata: attachment.metadata
    }
  end

  defp normalize(%__MODULE__{} = attachment) do
    Support.wrap_new(__MODULE__, fn -> normalize!(attachment) end)
  end

  defp normalize!(%__MODULE__{} = attachment) do
    %__MODULE__{
      attachment
      | metadata: Support.map!(attachment.metadata, "derived_state_attachment.metadata")
    }
  end
end
