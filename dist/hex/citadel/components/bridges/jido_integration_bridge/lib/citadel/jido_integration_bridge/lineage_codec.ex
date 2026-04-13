defmodule Citadel.JidoIntegrationBridge.LineageCodec do
  @moduledoc """
  Mandatory choke point for reconstructing Citadel-local vendored
  `Jido.Integration.V2` lineage structs.
  """

  alias Jido.Integration.V2.DerivedStateAttachment
  alias Jido.Integration.V2.EvidenceRef
  alias Jido.Integration.V2.GovernanceRef
  alias Jido.Integration.V2.ReviewProjection
  alias Jido.Integration.V2.SubjectRef

  @spec subject_ref!(SubjectRef.t() | map() | keyword()) :: SubjectRef.t()
  def subject_ref!(%SubjectRef{} = subject_ref), do: SubjectRef.new!(SubjectRef.dump(subject_ref))
  def subject_ref!(attrs), do: SubjectRef.new!(attrs)

  @spec evidence_ref!(EvidenceRef.t() | map() | keyword()) :: EvidenceRef.t()
  def evidence_ref!(%EvidenceRef{} = evidence_ref),
    do: EvidenceRef.new!(EvidenceRef.dump(evidence_ref))

  def evidence_ref!(attrs), do: EvidenceRef.new!(attrs)

  @spec governance_ref!(GovernanceRef.t() | map() | keyword()) :: GovernanceRef.t()
  def governance_ref!(%GovernanceRef{} = governance_ref),
    do: GovernanceRef.new!(GovernanceRef.dump(governance_ref))

  def governance_ref!(attrs), do: GovernanceRef.new!(attrs)

  @spec review_projection!(ReviewProjection.t() | map() | keyword()) :: ReviewProjection.t()
  def review_projection!(%ReviewProjection{} = projection),
    do: ReviewProjection.new!(ReviewProjection.dump(projection))

  def review_projection!(attrs), do: ReviewProjection.new!(attrs)

  @spec derived_state_attachment!(DerivedStateAttachment.t() | map() | keyword()) ::
          DerivedStateAttachment.t()
  def derived_state_attachment!(%DerivedStateAttachment{} = attachment) do
    DerivedStateAttachment.new!(DerivedStateAttachment.dump(attachment))
  end

  def derived_state_attachment!(attrs), do: DerivedStateAttachment.new!(attrs)
end
