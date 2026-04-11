defmodule Citadel.ProjectionBridge.ReviewProjectionAdapter do
  @moduledoc """
  Isolates `ReviewProjection` contract-shape evolution at the bridge edge.
  """

  alias Citadel.RuntimeObservation
  alias Jido.Integration.V2.ReviewProjection
  alias Jido.Integration.V2.SubjectRef

  @schema_version "review_projection.v1"
  @projection_name "citadel.runtime_observation"

  @spec normalize!(ReviewProjection.t() | RuntimeObservation.t() | map() | keyword()) :: ReviewProjection.t()
  def normalize!(%ReviewProjection{} = projection), do: ReviewProjection.new!(projection)
  def normalize!(%RuntimeObservation{} = observation), do: from_runtime_observation!(observation)

  def normalize!(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = Map.new(attrs)

    cond do
      Map.has_key?(attrs, :subject_ref) or Map.has_key?(attrs, "subject_ref") ->
        attrs |> RuntimeObservation.new!() |> from_runtime_observation!()

      true ->
        ReviewProjection.new!(attrs)
    end
  end

  defp from_runtime_observation!(%RuntimeObservation{} = observation) do
    ReviewProjection.new!(%{
      schema_version: @schema_version,
      projection: @projection_name,
      packet_ref: packet_ref(observation),
      subject: observation.subject_ref,
      selected_attempt: selected_attempt(observation),
      evidence_refs: observation.evidence_refs,
      governance_refs: observation.governance_refs
    })
  end

  defp packet_ref(%RuntimeObservation{} = observation) do
    case observation.evidence_refs do
      [%{packet_ref: packet_ref} | _] -> packet_ref
      _ -> "citadel://review/#{observation.observation_id}"
    end
  end

  defp selected_attempt(%RuntimeObservation{subject_ref: %SubjectRef{kind: :attempt} = subject_ref}),
    do: subject_ref

  defp selected_attempt(%RuntimeObservation{} = observation) do
    observation.evidence_refs
    |> Enum.find_value(fn evidence_ref ->
      case evidence_ref.subject do
        %SubjectRef{kind: :attempt} = subject_ref -> subject_ref
        _ -> nil
      end
    end)
  end
end
