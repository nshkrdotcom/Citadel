defmodule Jido.Integration.V2.ReviewProjection do
  @moduledoc """
  Contracts-only northbound review projection carried in review packet metadata.
  """

  alias Jido.Integration.V2.EvidenceRef
  alias Jido.Integration.V2.GovernanceRef
  alias Jido.Integration.V2.SubjectRef
  alias Jido.Integration.V2.Support

  @type t :: %__MODULE__{
          schema_version: String.t(),
          projection: String.t(),
          packet_ref: String.t(),
          subject: SubjectRef.t(),
          selected_attempt: SubjectRef.t() | nil,
          evidence_refs: [EvidenceRef.t()],
          governance_refs: [GovernanceRef.t()]
        }

  @type dump_t :: %{
          schema_version: String.t(),
          projection: String.t(),
          packet_ref: String.t(),
          subject: map(),
          selected_attempt: map() | nil,
          evidence_refs: [map()],
          governance_refs: [map()]
        }

  @enforce_keys [:schema_version, :projection, :packet_ref, :subject]
  defstruct schema_version: nil,
            projection: nil,
            packet_ref: nil,
            subject: nil,
            selected_attempt: nil,
            evidence_refs: [],
            governance_refs: []

  @spec new(map() | keyword() | t()) :: {:ok, t()} | {:error, Exception.t()}
  def new(%__MODULE__{} = projection), do: normalize(projection)

  def new(attrs) do
    Support.wrap_new(__MODULE__, fn ->
      attrs = Support.attrs!(attrs, __MODULE__)

      %__MODULE__{
        schema_version:
          Support.non_empty_string!(
            Support.fetch!(attrs, :schema_version, "review_projection.schema_version"),
            "review_projection.schema_version"
          ),
        projection:
          Support.non_empty_string!(
            Support.fetch!(attrs, :projection, "review_projection.projection"),
            "review_projection.projection"
          ),
        packet_ref:
          Support.non_empty_string!(
            Support.fetch!(attrs, :packet_ref, "review_projection.packet_ref"),
            "review_projection.packet_ref"
          ),
        subject:
          Support.struct!(
            Support.fetch!(attrs, :subject, "review_projection.subject"),
            SubjectRef,
            "review_projection.subject"
          ),
        selected_attempt:
          Support.optional_struct!(
            Support.fetch(attrs, :selected_attempt),
            SubjectRef,
            "review_projection.selected_attempt"
          ),
        evidence_refs:
          Support.list!(
            Support.fetch(attrs, :evidence_refs) || [],
            "review_projection.evidence_refs",
            fn item -> Support.struct!(item, EvidenceRef, "review_projection.evidence_refs") end
          ),
        governance_refs:
          Support.list!(
            Support.fetch(attrs, :governance_refs) || [],
            "review_projection.governance_refs",
            fn item ->
              Support.struct!(item, GovernanceRef, "review_projection.governance_refs")
            end
          )
      }
      |> normalize!()
    end)
  end

  @spec new!(map() | keyword() | t()) :: t()
  def new!(%__MODULE__{} = projection), do: normalize(projection) |> Support.unwrap_new!()
  def new!(attrs), do: new(attrs) |> Support.unwrap_new!()

  @spec dump(t()) :: dump_t()
  def dump(%__MODULE__{} = projection) do
    %{
      schema_version: projection.schema_version,
      projection: projection.projection,
      packet_ref: projection.packet_ref,
      subject: SubjectRef.dump(projection.subject),
      selected_attempt: maybe_dump_selected_attempt(projection.selected_attempt),
      evidence_refs: Enum.map(projection.evidence_refs, &EvidenceRef.dump/1),
      governance_refs: Enum.map(projection.governance_refs, &GovernanceRef.dump/1)
    }
  end

  defp normalize(%__MODULE__{} = projection) do
    Support.wrap_new(__MODULE__, fn -> normalize!(projection) end)
  end

  defp normalize!(%__MODULE__{} = projection) do
    case projection.selected_attempt do
      nil ->
        projection

      %SubjectRef{kind: :attempt} ->
        projection

      %SubjectRef{} = subject_ref ->
        raise ArgumentError,
              "review_projection.selected_attempt must be an attempt subject, got: #{inspect(subject_ref.kind)}"
    end
  end

  defp maybe_dump_selected_attempt(nil), do: nil
  defp maybe_dump_selected_attempt(%SubjectRef{} = subject_ref), do: SubjectRef.dump(subject_ref)
end
