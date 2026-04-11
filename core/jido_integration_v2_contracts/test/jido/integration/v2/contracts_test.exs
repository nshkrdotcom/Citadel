defmodule Jido.Integration.V2.ContractsTest do
  use ExUnit.Case, async: true

  alias Jido.Integration.V2.DerivedStateAttachment
  alias Jido.Integration.V2.EvidenceRef
  alias Jido.Integration.V2.GovernanceRef
  alias Jido.Integration.V2.ReviewProjection
  alias Jido.Integration.V2.SubjectRef

  test "subject refs derive canonical refs" do
    subject_ref = SubjectRef.new!(%{kind: :run, id: "run-1"})

    assert subject_ref.ref == "jido://v2/subject/run/run-1"
    assert SubjectRef.dump(subject_ref).kind == :run
  end

  test "higher-order contracts normalize nested lineage values" do
    subject = SubjectRef.new!(%{kind: :run, id: "run-1"})

    evidence =
      EvidenceRef.new!(%{kind: :event, id: "event-1", packet_ref: "packet-1", subject: subject})

    governance =
      GovernanceRef.new!(%{
        kind: :policy_decision,
        id: "gov-1",
        subject: subject,
        evidence: [evidence]
      })

    projection =
      ReviewProjection.new!(%{
        schema_version: "review_projection.v1",
        projection: "citadel.runtime_observation",
        packet_ref: "packet-1",
        subject: subject,
        selected_attempt: SubjectRef.new!(%{kind: :attempt, id: "run-1:1"}),
        evidence_refs: [evidence],
        governance_refs: [governance]
      })

    attachment =
      DerivedStateAttachment.new!(%{
        subject: subject,
        evidence_refs: [evidence],
        governance_refs: [governance],
        metadata: %{"kind" => "derived_summary"}
      })

    assert projection.subject.ref == "jido://v2/subject/run/run-1"
    assert attachment.metadata["kind"] == "derived_summary"
  end
end
