defmodule Citadel.SessionContinuityCommit do
  @moduledoc """
  Single atomic continuity-write command crossing the `SessionDirectory` seam.
  """

  alias Citadel.ContractCore.Value
  alias Citadel.PersistedSessionBlob

  @fields [
    :session_id,
    :expected_continuity_revision,
    :expected_owner_incarnation,
    :persisted_blob,
    :extensions
  ]

  @type t :: %__MODULE__{
          session_id: String.t(),
          expected_continuity_revision: non_neg_integer(),
          expected_owner_incarnation: pos_integer(),
          persisted_blob: PersistedSessionBlob.t(),
          extensions: map()
        }

  @enforce_keys @fields
  defstruct @fields

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.SessionContinuityCommit", @fields)

    commit = %__MODULE__{
      session_id:
        Value.required(attrs, :session_id, "Citadel.SessionContinuityCommit", fn value ->
          Value.string!(value, "Citadel.SessionContinuityCommit.session_id")
        end),
      expected_continuity_revision:
        Value.required(
          attrs,
          :expected_continuity_revision,
          "Citadel.SessionContinuityCommit",
          fn value ->
            Value.non_neg_integer!(
              value,
              "Citadel.SessionContinuityCommit.expected_continuity_revision"
            )
          end
        ),
      expected_owner_incarnation:
        Value.required(
          attrs,
          :expected_owner_incarnation,
          "Citadel.SessionContinuityCommit",
          fn value ->
            Value.positive_integer!(
              value,
              "Citadel.SessionContinuityCommit.expected_owner_incarnation"
            )
          end
        ),
      persisted_blob:
        Value.required(attrs, :persisted_blob, "Citadel.SessionContinuityCommit", fn value ->
          Value.module!(
            value,
            PersistedSessionBlob,
            "Citadel.SessionContinuityCommit.persisted_blob"
          )
        end),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.SessionContinuityCommit",
          fn value ->
            Value.json_object!(value, "Citadel.SessionContinuityCommit.extensions")
          end,
          %{}
        )
    }

    validate_commit_semantics!(commit)
  end

  def dump(%__MODULE__{} = commit) do
    %{
      session_id: commit.session_id,
      expected_continuity_revision: commit.expected_continuity_revision,
      expected_owner_incarnation: commit.expected_owner_incarnation,
      persisted_blob: PersistedSessionBlob.dump(commit.persisted_blob),
      extensions: commit.extensions
    }
  end

  def owner_transition(%__MODULE__{} = commit) do
    case commit.persisted_blob.envelope.owner_incarnation - commit.expected_owner_incarnation do
      0 -> :same_owner
      1 -> :ownership_claim
      _ -> :invalid
    end
  end

  defp validate_commit_semantics!(%__MODULE__{} = commit) do
    envelope = commit.persisted_blob.envelope

    if commit.session_id != commit.persisted_blob.session_id do
      raise ArgumentError,
            "Citadel.SessionContinuityCommit.session_id must match persisted_blob.session_id"
    end

    if envelope.continuity_revision != commit.expected_continuity_revision + 1 do
      raise ArgumentError,
            "Citadel.SessionContinuityCommit requires persisted continuity_revision to advance by exactly 1"
    end

    if owner_transition(commit) == :invalid do
      raise ArgumentError,
            "Citadel.SessionContinuityCommit owner_incarnation must stay the same or advance by exactly 1"
    end

    commit
  end
end
