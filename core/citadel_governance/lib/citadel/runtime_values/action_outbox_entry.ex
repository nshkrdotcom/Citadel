defmodule Citadel.ActionOutboxEntry do
  @moduledoc """
  Replay-safe persisted local action envelope.
  """

  alias Citadel.BackoffPolicy
  alias Citadel.ContractCore.Value
  alias Citadel.LocalAction
  alias Citadel.StalenessRequirements

  @schema_version 1
  @allowed_replay_status [
    :pending,
    :dispatched,
    :submission_accepted,
    :completed,
    :dead_letter,
    :superseded
  ]
  @allowed_ordering_modes [:strict, :relaxed]
  @allowed_staleness_modes [:requires_check, :stale_exempt]
  @schema [
    schema_version: {:literal, @schema_version},
    entry_id: :string,
    causal_group_id: :string,
    action: {:struct, LocalAction},
    inserted_at: :datetime,
    replay_status: {:enum, @allowed_replay_status},
    submission_key: :string,
    submission_receipt_ref: :string,
    durable_receipt_ref: :string,
    submission_rejection: {:map, :json},
    attempt_count: :non_neg_integer,
    max_attempts: :positive_integer,
    backoff_policy: {:struct, BackoffPolicy},
    next_attempt_at: :datetime,
    last_error_code: :string,
    dead_letter_reason: :string,
    ordering_mode: {:enum, @allowed_ordering_modes},
    staleness_mode: {:enum, @allowed_staleness_modes},
    staleness_requirements: {:struct, StalenessRequirements},
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type replay_status ::
          :pending
          | :dispatched
          | :submission_accepted
          | :completed
          | :dead_letter
          | :superseded
  @type ordering_mode :: :strict | :relaxed
  @type staleness_mode :: :requires_check | :stale_exempt

  @type t :: %__MODULE__{
          schema_version: pos_integer(),
          entry_id: String.t(),
          causal_group_id: String.t(),
          action: LocalAction.t(),
          inserted_at: DateTime.t(),
          replay_status: replay_status(),
          submission_key: String.t() | nil,
          submission_receipt_ref: String.t() | nil,
          durable_receipt_ref: String.t() | nil,
          submission_rejection: map() | nil,
          attempt_count: non_neg_integer(),
          max_attempts: pos_integer(),
          backoff_policy: BackoffPolicy.t(),
          next_attempt_at: DateTime.t() | nil,
          last_error_code: String.t() | nil,
          dead_letter_reason: String.t() | nil,
          ordering_mode: ordering_mode(),
          staleness_mode: staleness_mode(),
          staleness_requirements: StalenessRequirements.t() | nil,
          extensions: map()
        }

  @enforce_keys [
    :schema_version,
    :entry_id,
    :causal_group_id,
    :action,
    :inserted_at,
    :replay_status,
    :attempt_count,
    :max_attempts,
    :backoff_policy,
    :ordering_mode,
    :staleness_mode
  ]
  defstruct schema_version: @schema_version,
            entry_id: nil,
            causal_group_id: nil,
            action: nil,
            inserted_at: nil,
            replay_status: :pending,
            submission_key: nil,
            submission_receipt_ref: nil,
            durable_receipt_ref: nil,
            submission_rejection: nil,
            attempt_count: 0,
            max_attempts: 1,
            backoff_policy: nil,
            next_attempt_at: nil,
            last_error_code: nil,
            dead_letter_reason: nil,
            ordering_mode: :strict,
            staleness_mode: :requires_check,
            staleness_requirements: nil,
            extensions: %{}

  def schema, do: @schema
  def schema_version, do: @schema_version
  def allowed_replay_status, do: @allowed_replay_status
  def allowed_ordering_modes, do: @allowed_ordering_modes
  def allowed_staleness_modes, do: @allowed_staleness_modes

  def new!(%__MODULE__{} = entry) do
    entry
    |> dump()
    |> new!()
  end

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.ActionOutboxEntry", @fields)

    entry = %__MODULE__{
      schema_version:
        Value.required(attrs, :schema_version, "Citadel.ActionOutboxEntry", fn value ->
          if value == @schema_version do
            value
          else
            raise ArgumentError,
                  "Citadel.ActionOutboxEntry.schema_version must be #{@schema_version}, got: #{inspect(value)}"
          end
        end),
      entry_id:
        Value.required(attrs, :entry_id, "Citadel.ActionOutboxEntry", fn value ->
          Value.string!(value, "Citadel.ActionOutboxEntry.entry_id")
        end),
      causal_group_id:
        Value.required(attrs, :causal_group_id, "Citadel.ActionOutboxEntry", fn value ->
          Value.string!(value, "Citadel.ActionOutboxEntry.causal_group_id")
        end),
      action:
        Value.required(attrs, :action, "Citadel.ActionOutboxEntry", fn value ->
          Value.module!(value, LocalAction, "Citadel.ActionOutboxEntry.action")
        end),
      inserted_at:
        Value.required(attrs, :inserted_at, "Citadel.ActionOutboxEntry", fn value ->
          Value.datetime!(value, "Citadel.ActionOutboxEntry.inserted_at")
        end),
      replay_status:
        Value.required(attrs, :replay_status, "Citadel.ActionOutboxEntry", fn value ->
          Value.enum!(value, @allowed_replay_status, "Citadel.ActionOutboxEntry.replay_status")
        end),
      submission_key:
        Value.optional(
          attrs,
          :submission_key,
          "Citadel.ActionOutboxEntry",
          fn value ->
            Value.string!(value, "Citadel.ActionOutboxEntry.submission_key")
          end,
          nil
        ),
      submission_receipt_ref:
        Value.optional(
          attrs,
          :submission_receipt_ref,
          "Citadel.ActionOutboxEntry",
          fn value ->
            Value.string!(value, "Citadel.ActionOutboxEntry.submission_receipt_ref")
          end,
          nil
        ),
      durable_receipt_ref:
        Value.optional(
          attrs,
          :durable_receipt_ref,
          "Citadel.ActionOutboxEntry",
          fn value ->
            Value.string!(value, "Citadel.ActionOutboxEntry.durable_receipt_ref")
          end,
          nil
        ),
      submission_rejection:
        Value.optional(
          attrs,
          :submission_rejection,
          "Citadel.ActionOutboxEntry",
          fn value ->
            Value.json_object!(value, "Citadel.ActionOutboxEntry.submission_rejection")
          end,
          nil
        ),
      attempt_count:
        Value.required(attrs, :attempt_count, "Citadel.ActionOutboxEntry", fn value ->
          Value.non_neg_integer!(value, "Citadel.ActionOutboxEntry.attempt_count")
        end),
      max_attempts:
        Value.required(attrs, :max_attempts, "Citadel.ActionOutboxEntry", fn value ->
          Value.positive_integer!(value, "Citadel.ActionOutboxEntry.max_attempts")
        end),
      backoff_policy:
        Value.required(attrs, :backoff_policy, "Citadel.ActionOutboxEntry", fn value ->
          Value.module!(value, BackoffPolicy, "Citadel.ActionOutboxEntry.backoff_policy")
        end),
      next_attempt_at:
        Value.optional(
          attrs,
          :next_attempt_at,
          "Citadel.ActionOutboxEntry",
          fn value ->
            Value.datetime!(value, "Citadel.ActionOutboxEntry.next_attempt_at")
          end,
          nil
        ),
      last_error_code:
        Value.optional(
          attrs,
          :last_error_code,
          "Citadel.ActionOutboxEntry",
          fn value ->
            Value.string!(value, "Citadel.ActionOutboxEntry.last_error_code")
          end,
          nil
        ),
      dead_letter_reason:
        Value.optional(
          attrs,
          :dead_letter_reason,
          "Citadel.ActionOutboxEntry",
          fn value ->
            Value.string!(value, "Citadel.ActionOutboxEntry.dead_letter_reason")
          end,
          nil
        ),
      ordering_mode:
        Value.required(attrs, :ordering_mode, "Citadel.ActionOutboxEntry", fn value ->
          Value.enum!(value, @allowed_ordering_modes, "Citadel.ActionOutboxEntry.ordering_mode")
        end),
      staleness_mode:
        Value.required(attrs, :staleness_mode, "Citadel.ActionOutboxEntry", fn value ->
          Value.enum!(value, @allowed_staleness_modes, "Citadel.ActionOutboxEntry.staleness_mode")
        end),
      staleness_requirements:
        Value.optional(
          attrs,
          :staleness_requirements,
          "Citadel.ActionOutboxEntry",
          fn value ->
            Value.module!(
              value,
              StalenessRequirements,
              "Citadel.ActionOutboxEntry.staleness_requirements"
            )
          end,
          nil
        ),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.ActionOutboxEntry",
          fn value ->
            Value.json_object!(value, "Citadel.ActionOutboxEntry.extensions")
          end,
          %{}
        )
    }

    validate_staleness_mode!(entry)
    validate_submission_state!(entry)
    validate_terminal_state!(entry)
    validate_attempt_bounds!(entry)
    entry
  end

  def dump(%__MODULE__{} = entry) do
    %{
      schema_version: entry.schema_version,
      entry_id: entry.entry_id,
      causal_group_id: entry.causal_group_id,
      action: LocalAction.dump(entry.action),
      inserted_at: entry.inserted_at,
      replay_status: entry.replay_status,
      submission_key: entry.submission_key,
      submission_receipt_ref: entry.submission_receipt_ref,
      durable_receipt_ref: entry.durable_receipt_ref,
      submission_rejection: entry.submission_rejection,
      attempt_count: entry.attempt_count,
      max_attempts: entry.max_attempts,
      backoff_policy: BackoffPolicy.dump(entry.backoff_policy),
      next_attempt_at: entry.next_attempt_at,
      last_error_code: entry.last_error_code,
      dead_letter_reason: entry.dead_letter_reason,
      ordering_mode: entry.ordering_mode,
      staleness_mode: entry.staleness_mode,
      staleness_requirements: maybe_dump(entry.staleness_requirements),
      extensions: entry.extensions
    }
  end

  def replayable?(%__MODULE__{replay_status: status}) when status in [:pending, :dispatched],
    do: true

  def replayable?(%__MODULE__{}), do: false

  defp validate_submission_state!(%__MODULE__{
         replay_status: :submission_accepted,
         submission_key: nil
       }) do
    raise ArgumentError,
          "Citadel.ActionOutboxEntry submission-accepted entries require submission_key"
  end

  defp validate_submission_state!(%__MODULE__{
         replay_status: :submission_accepted,
         submission_receipt_ref: nil
       }) do
    raise ArgumentError,
          "Citadel.ActionOutboxEntry submission-accepted entries require submission_receipt_ref"
  end

  defp validate_submission_state!(%__MODULE__{
         replay_status: :submission_accepted,
         submission_rejection: rejection
       })
       when not is_nil(rejection) do
    raise ArgumentError,
          "Citadel.ActionOutboxEntry submission-accepted entries must not carry submission_rejection"
  end

  defp validate_submission_state!(%__MODULE__{
         submission_receipt_ref: receipt_ref,
         submission_key: nil
       })
       when not is_nil(receipt_ref) do
    raise ArgumentError,
          "Citadel.ActionOutboxEntry submission_receipt_ref requires submission_key"
  end

  defp validate_submission_state!(%__MODULE__{
         submission_rejection: rejection,
         submission_key: nil
       })
       when not is_nil(rejection) do
    raise ArgumentError,
          "Citadel.ActionOutboxEntry submission_rejection requires submission_key"
  end

  defp validate_submission_state!(entry), do: entry

  defp validate_staleness_mode!(%__MODULE__{
         staleness_mode: :requires_check,
         staleness_requirements: nil
       }) do
    raise ArgumentError,
          "Citadel.ActionOutboxEntry requires explicit staleness_requirements when staleness_mode is :requires_check"
  end

  defp validate_staleness_mode!(%__MODULE__{
         staleness_mode: :stale_exempt,
         staleness_requirements: %StalenessRequirements{}
       }) do
    raise ArgumentError,
          "Citadel.ActionOutboxEntry stale-exempt entries must not also carry staleness_requirements"
  end

  defp validate_staleness_mode!(entry), do: entry

  defp validate_terminal_state!(%__MODULE__{replay_status: :completed, durable_receipt_ref: nil}) do
    raise ArgumentError,
          "Citadel.ActionOutboxEntry completed entries require durable_receipt_ref"
  end

  defp validate_terminal_state!(%__MODULE__{replay_status: :dead_letter, dead_letter_reason: nil}) do
    raise ArgumentError,
          "Citadel.ActionOutboxEntry dead-letter entries require dead_letter_reason"
  end

  defp validate_terminal_state!(entry), do: entry

  defp validate_attempt_bounds!(%__MODULE__{attempt_count: attempts, max_attempts: max_attempts})
       when attempts <= max_attempts,
       do: :ok

  defp validate_attempt_bounds!(%__MODULE__{} = entry) do
    raise ArgumentError,
          "Citadel.ActionOutboxEntry.attempt_count must be <= max_attempts, got #{entry.attempt_count} > #{entry.max_attempts}"
  end

  defp maybe_dump(nil), do: nil
  defp maybe_dump(%module{} = struct), do: module.dump(struct)
end
