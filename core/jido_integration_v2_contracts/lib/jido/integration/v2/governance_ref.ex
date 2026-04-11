defmodule Jido.Integration.V2.GovernanceRef do
  @moduledoc """
  Stable reference to governance lineage such as approval, denial, override, rollback, or policy decisions.
  """

  alias Jido.Integration.V2.EvidenceRef
  alias Jido.Integration.V2.SubjectRef
  alias Jido.Integration.V2.Support

  @kinds [:approval, :denial, :override, :rollback, :policy_decision]

  @type kind :: :approval | :denial | :override | :rollback | :policy_decision

  @type t :: %__MODULE__{
          ref: String.t(),
          kind: kind(),
          id: String.t(),
          subject: SubjectRef.t(),
          evidence: [EvidenceRef.t()],
          metadata: map()
        }

  @enforce_keys [:kind, :id, :subject]
  defstruct ref: nil, kind: nil, id: nil, subject: nil, evidence: [], metadata: %{}

  @spec new(map() | keyword() | t()) :: {:ok, t()} | {:error, Exception.t()}
  def new(%__MODULE__{} = governance_ref), do: normalize(governance_ref)

  def new(attrs) do
    Support.wrap_new(__MODULE__, fn ->
      attrs = Support.attrs!(attrs, __MODULE__)

      %__MODULE__{
        ref: Support.fetch(attrs, :ref),
        kind:
          Support.enum!(
            Support.fetch!(attrs, :kind, "governance_ref.kind"),
            @kinds,
            "governance_ref.kind"
          ),
        id:
          Support.non_empty_string!(
            Support.fetch!(attrs, :id, "governance_ref.id"),
            "governance_ref.id"
          ),
        subject:
          Support.struct!(
            Support.fetch!(attrs, :subject, "governance_ref.subject"),
            SubjectRef,
            "governance_ref.subject"
          ),
        evidence:
          Support.list!(
            Support.fetch(attrs, :evidence) || [],
            "governance_ref.evidence",
            fn item ->
              Support.struct!(item, EvidenceRef, "governance_ref.evidence")
            end
          ),
        metadata: Support.map!(Support.fetch(attrs, :metadata) || %{}, "governance_ref.metadata")
      }
      |> normalize!()
    end)
  end

  @spec new!(map() | keyword() | t()) :: t()
  def new!(%__MODULE__{} = governance_ref),
    do: normalize(governance_ref) |> Support.unwrap_new!()

  def new!(attrs), do: new(attrs) |> Support.unwrap_new!()

  @spec ref(kind(), String.t()) :: String.t()
  def ref(kind, id), do: Support.reference_uri("governance", kind, id)

  @spec dump(t()) :: %{
          ref: String.t(),
          kind: kind(),
          id: String.t(),
          subject: map(),
          evidence: [map()],
          metadata: map()
        }
  def dump(%__MODULE__{} = governance_ref) do
    %{
      ref: governance_ref.ref,
      kind: governance_ref.kind,
      id: governance_ref.id,
      subject: SubjectRef.dump(governance_ref.subject),
      evidence: Enum.map(governance_ref.evidence, &EvidenceRef.dump/1),
      metadata: governance_ref.metadata
    }
  end

  defp normalize(%__MODULE__{} = governance_ref) do
    Support.wrap_new(__MODULE__, fn -> normalize!(governance_ref) end)
  end

  defp normalize!(%__MODULE__{} = governance_ref) do
    expected_ref = ref(governance_ref.kind, governance_ref.id)

    if is_nil(governance_ref.ref) or governance_ref.ref == expected_ref do
      %__MODULE__{
        governance_ref
        | ref: expected_ref,
          metadata: Support.map!(governance_ref.metadata, "governance_ref.metadata")
      }
    else
      raise ArgumentError,
            "governance_ref.ref must match kind and id: #{inspect({governance_ref.kind, governance_ref.id, governance_ref.ref})}"
    end
  end
end
