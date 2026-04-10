defmodule Citadel.StalenessRequirements do
  @moduledoc """
  Explicit replay-safe stale-check contract for one persisted action.
  """

  alias Citadel.ContractCore.Value

  @schema [
    snapshot_seq: :non_neg_integer,
    policy_epoch: :non_neg_integer,
    topology_epoch: :non_neg_integer,
    scope_catalog_epoch: :non_neg_integer,
    service_admission_epoch: :non_neg_integer,
    project_binding_epoch: :non_neg_integer,
    boundary_epoch: :non_neg_integer,
    required_binding_id: :string,
    required_boundary_ref: :string,
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          snapshot_seq: non_neg_integer() | nil,
          policy_epoch: non_neg_integer() | nil,
          topology_epoch: non_neg_integer() | nil,
          scope_catalog_epoch: non_neg_integer() | nil,
          service_admission_epoch: non_neg_integer() | nil,
          project_binding_epoch: non_neg_integer() | nil,
          boundary_epoch: non_neg_integer() | nil,
          required_binding_id: String.t() | nil,
          required_boundary_ref: String.t() | nil,
          extensions: map()
        }

  @enforce_keys []
  defstruct snapshot_seq: nil,
            policy_epoch: nil,
            topology_epoch: nil,
            scope_catalog_epoch: nil,
            service_admission_epoch: nil,
            project_binding_epoch: nil,
            boundary_epoch: nil,
            required_binding_id: nil,
            required_boundary_ref: nil,
            extensions: %{}

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.StalenessRequirements", @fields)

    requirements = %__MODULE__{
      snapshot_seq:
        Value.optional(attrs, :snapshot_seq, "Citadel.StalenessRequirements", fn value ->
          Value.non_neg_integer!(value, "Citadel.StalenessRequirements.snapshot_seq")
        end, nil),
      policy_epoch:
        Value.optional(attrs, :policy_epoch, "Citadel.StalenessRequirements", fn value ->
          Value.non_neg_integer!(value, "Citadel.StalenessRequirements.policy_epoch")
        end, nil),
      topology_epoch:
        Value.optional(attrs, :topology_epoch, "Citadel.StalenessRequirements", fn value ->
          Value.non_neg_integer!(value, "Citadel.StalenessRequirements.topology_epoch")
        end, nil),
      scope_catalog_epoch:
        Value.optional(attrs, :scope_catalog_epoch, "Citadel.StalenessRequirements", fn value ->
          Value.non_neg_integer!(value, "Citadel.StalenessRequirements.scope_catalog_epoch")
        end, nil),
      service_admission_epoch:
        Value.optional(attrs, :service_admission_epoch, "Citadel.StalenessRequirements", fn value ->
          Value.non_neg_integer!(value, "Citadel.StalenessRequirements.service_admission_epoch")
        end, nil),
      project_binding_epoch:
        Value.optional(attrs, :project_binding_epoch, "Citadel.StalenessRequirements", fn value ->
          Value.non_neg_integer!(value, "Citadel.StalenessRequirements.project_binding_epoch")
        end, nil),
      boundary_epoch:
        Value.optional(attrs, :boundary_epoch, "Citadel.StalenessRequirements", fn value ->
          Value.non_neg_integer!(value, "Citadel.StalenessRequirements.boundary_epoch")
        end, nil),
      required_binding_id:
        Value.optional(attrs, :required_binding_id, "Citadel.StalenessRequirements", fn value ->
          Value.string!(value, "Citadel.StalenessRequirements.required_binding_id")
        end, nil),
      required_boundary_ref:
        Value.optional(attrs, :required_boundary_ref, "Citadel.StalenessRequirements", fn value ->
          Value.string!(value, "Citadel.StalenessRequirements.required_boundary_ref")
        end, nil),
      extensions:
        Value.optional(attrs, :extensions, "Citadel.StalenessRequirements", fn value ->
          Value.json_object!(value, "Citadel.StalenessRequirements.extensions")
        end, %{})
    }

    meaningful =
      Map.take(requirements, [
        :policy_epoch,
        :topology_epoch,
        :scope_catalog_epoch,
        :service_admission_epoch,
        :project_binding_epoch,
        :boundary_epoch,
        :required_binding_id,
        :required_boundary_ref
      ])
      |> Map.values()
      |> Enum.reject(&is_nil/1)

    if meaningful == [] do
      raise ArgumentError,
            "Citadel.StalenessRequirements must carry an explicit epoch, binding, or boundary comparison"
    end

    requirements
  end

  def dump(%__MODULE__{} = requirements) do
    %{
      snapshot_seq: requirements.snapshot_seq,
      policy_epoch: requirements.policy_epoch,
      topology_epoch: requirements.topology_epoch,
      scope_catalog_epoch: requirements.scope_catalog_epoch,
      service_admission_epoch: requirements.service_admission_epoch,
      project_binding_epoch: requirements.project_binding_epoch,
      boundary_epoch: requirements.boundary_epoch,
      required_binding_id: requirements.required_binding_id,
      required_boundary_ref: requirements.required_boundary_ref,
      extensions: requirements.extensions
    }
  end
end

defmodule Citadel.BackoffPolicy do
  @moduledoc """
  Explicit deterministic retry schedule contract.
  """

  alias Citadel.ContractCore.Value

  @allowed_strategies [:fixed, :linear, :exponential]
  @allowed_jitter_modes [:none, :entry_stable]
  @schema [
    strategy: {:enum, @allowed_strategies},
    base_delay_ms: :non_neg_integer,
    max_delay_ms: :non_neg_integer,
    linear_step_ms: :non_neg_integer,
    multiplier: :positive_integer,
    jitter_mode: {:enum, @allowed_jitter_modes},
    jitter_window_ms: :non_neg_integer,
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type strategy :: :fixed | :linear | :exponential
  @type jitter_mode :: :none | :entry_stable

  @type t :: %__MODULE__{
          strategy: strategy(),
          base_delay_ms: non_neg_integer(),
          max_delay_ms: non_neg_integer() | nil,
          linear_step_ms: non_neg_integer() | nil,
          multiplier: pos_integer() | nil,
          jitter_mode: jitter_mode(),
          jitter_window_ms: non_neg_integer(),
          extensions: map()
        }

  @enforce_keys [:strategy, :base_delay_ms, :jitter_mode, :jitter_window_ms]
  defstruct strategy: :fixed,
            base_delay_ms: 0,
            max_delay_ms: nil,
            linear_step_ms: nil,
            multiplier: nil,
            jitter_mode: :none,
            jitter_window_ms: 0,
            extensions: %{}

  def schema, do: @schema
  def allowed_strategies, do: @allowed_strategies
  def allowed_jitter_modes, do: @allowed_jitter_modes

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.BackoffPolicy", @fields)

    policy = %__MODULE__{
      strategy:
        Value.required(attrs, :strategy, "Citadel.BackoffPolicy", fn value ->
          Value.enum!(value, @allowed_strategies, "Citadel.BackoffPolicy.strategy")
        end),
      base_delay_ms:
        Value.required(attrs, :base_delay_ms, "Citadel.BackoffPolicy", fn value ->
          Value.non_neg_integer!(value, "Citadel.BackoffPolicy.base_delay_ms")
        end),
      max_delay_ms:
        Value.optional(attrs, :max_delay_ms, "Citadel.BackoffPolicy", fn value ->
          Value.non_neg_integer!(value, "Citadel.BackoffPolicy.max_delay_ms")
        end, nil),
      linear_step_ms:
        Value.optional(attrs, :linear_step_ms, "Citadel.BackoffPolicy", fn value ->
          Value.non_neg_integer!(value, "Citadel.BackoffPolicy.linear_step_ms")
        end, nil),
      multiplier:
        Value.optional(attrs, :multiplier, "Citadel.BackoffPolicy", fn value ->
          Value.positive_integer!(value, "Citadel.BackoffPolicy.multiplier")
        end, nil),
      jitter_mode:
        Value.required(attrs, :jitter_mode, "Citadel.BackoffPolicy", fn value ->
          Value.enum!(value, @allowed_jitter_modes, "Citadel.BackoffPolicy.jitter_mode")
        end),
      jitter_window_ms:
        Value.required(attrs, :jitter_window_ms, "Citadel.BackoffPolicy", fn value ->
          Value.non_neg_integer!(value, "Citadel.BackoffPolicy.jitter_window_ms")
        end),
      extensions:
        Value.optional(attrs, :extensions, "Citadel.BackoffPolicy", fn value ->
          Value.json_object!(value, "Citadel.BackoffPolicy.extensions")
        end, %{})
    }

    validate_strategy_specific_requirements!(policy)
  end

  def dump(%__MODULE__{} = policy) do
    %{
      strategy: policy.strategy,
      base_delay_ms: policy.base_delay_ms,
      max_delay_ms: policy.max_delay_ms,
      linear_step_ms: policy.linear_step_ms,
      multiplier: policy.multiplier,
      jitter_mode: policy.jitter_mode,
      jitter_window_ms: policy.jitter_window_ms,
      extensions: policy.extensions
    }
  end

  def compute_delay_ms!(%__MODULE__{} = policy, entry_id, attempt_count) do
    entry_id = Value.string!(entry_id, "Citadel.BackoffPolicy entry_id")
    attempt_count = Value.non_neg_integer!(attempt_count, "Citadel.BackoffPolicy attempt_count")

    base_delay =
      case policy.strategy do
        :fixed ->
          policy.base_delay_ms

        :linear ->
          policy.base_delay_ms + policy.linear_step_ms * max(attempt_count - 1, 0)

        :exponential ->
          round(policy.base_delay_ms * :math.pow(policy.multiplier, max(attempt_count - 1, 0)))
      end

    delay_with_jitter =
      base_delay +
        case policy.jitter_mode do
          :none -> 0
          :entry_stable -> jitter_offset_ms(policy, entry_id)
        end

    cap_delay(delay_with_jitter, policy.max_delay_ms)
  end

  defp jitter_offset_ms(%__MODULE__{jitter_window_ms: 0}, _entry_id), do: 0

  defp jitter_offset_ms(%__MODULE__{jitter_window_ms: window_ms}, entry_id) do
    :erlang.phash2(entry_id, window_ms)
  end

  defp cap_delay(delay, nil), do: delay
  defp cap_delay(delay, max_delay), do: min(delay, max_delay)

  defp validate_strategy_specific_requirements!(%__MODULE__{strategy: :linear, linear_step_ms: nil}) do
    raise ArgumentError, "Citadel.BackoffPolicy.linear_step_ms is required for linear strategy"
  end

  defp validate_strategy_specific_requirements!(%__MODULE__{strategy: :exponential, multiplier: nil}) do
    raise ArgumentError, "Citadel.BackoffPolicy.multiplier is required for exponential strategy"
  end

  defp validate_strategy_specific_requirements!(%__MODULE__{strategy: :exponential, multiplier: 1}) do
    raise ArgumentError, "Citadel.BackoffPolicy.multiplier must be greater than 1 for exponential strategy"
  end

  defp validate_strategy_specific_requirements!(policy), do: policy
end

defmodule Citadel.LocalAction do
  @moduledoc """
  Deferred post-commit local action.
  """

  alias Citadel.ContractCore.Value

  @schema [
    action_kind: :string,
    payload: {:map, :json},
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          action_kind: String.t(),
          payload: map(),
          extensions: map()
        }

  @enforce_keys @fields
  defstruct @fields

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.LocalAction", @fields)

    %__MODULE__{
      action_kind:
        Value.required(attrs, :action_kind, "Citadel.LocalAction", fn value ->
          Value.string!(value, "Citadel.LocalAction.action_kind")
        end),
      payload:
        Value.required(attrs, :payload, "Citadel.LocalAction", fn value ->
          Value.json_object!(value, "Citadel.LocalAction.payload")
        end),
      extensions:
        Value.optional(attrs, :extensions, "Citadel.LocalAction", fn value ->
          Value.json_object!(value, "Citadel.LocalAction.extensions")
        end, %{})
    }
  end

  def dump(%__MODULE__{} = action) do
    %{
      action_kind: action.action_kind,
      payload: action.payload,
      extensions: action.extensions
    }
  end
end

defmodule Citadel.ActionOutboxEntry do
  @moduledoc """
  Replay-safe persisted local action envelope.
  """

  alias Citadel.BackoffPolicy
  alias Citadel.ContractCore.Value
  alias Citadel.LocalAction
  alias Citadel.StalenessRequirements

  @schema_version 1
  @allowed_replay_status [:pending, :dispatched, :completed, :dead_letter, :superseded]
  @allowed_ordering_modes [:strict, :relaxed]
  @allowed_staleness_modes [:requires_check, :stale_exempt]
  @schema [
    schema_version: {:literal, @schema_version},
    entry_id: :string,
    causal_group_id: :string,
    action: {:struct, LocalAction},
    inserted_at: :datetime,
    replay_status: {:enum, @allowed_replay_status},
    durable_receipt_ref: :string,
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

  @type replay_status :: :pending | :dispatched | :completed | :dead_letter | :superseded
  @type ordering_mode :: :strict | :relaxed
  @type staleness_mode :: :requires_check | :stale_exempt

  @type t :: %__MODULE__{
          schema_version: pos_integer(),
          entry_id: String.t(),
          causal_group_id: String.t(),
          action: LocalAction.t(),
          inserted_at: DateTime.t(),
          replay_status: replay_status(),
          durable_receipt_ref: String.t() | nil,
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
            durable_receipt_ref: nil,
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
      durable_receipt_ref:
        Value.optional(attrs, :durable_receipt_ref, "Citadel.ActionOutboxEntry", fn value ->
          Value.string!(value, "Citadel.ActionOutboxEntry.durable_receipt_ref")
        end, nil),
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
        Value.optional(attrs, :next_attempt_at, "Citadel.ActionOutboxEntry", fn value ->
          Value.datetime!(value, "Citadel.ActionOutboxEntry.next_attempt_at")
        end, nil),
      last_error_code:
        Value.optional(attrs, :last_error_code, "Citadel.ActionOutboxEntry", fn value ->
          Value.string!(value, "Citadel.ActionOutboxEntry.last_error_code")
        end, nil),
      dead_letter_reason:
        Value.optional(attrs, :dead_letter_reason, "Citadel.ActionOutboxEntry", fn value ->
          Value.string!(value, "Citadel.ActionOutboxEntry.dead_letter_reason")
        end, nil),
      ordering_mode:
        Value.required(attrs, :ordering_mode, "Citadel.ActionOutboxEntry", fn value ->
          Value.enum!(value, @allowed_ordering_modes, "Citadel.ActionOutboxEntry.ordering_mode")
        end),
      staleness_mode:
        Value.required(attrs, :staleness_mode, "Citadel.ActionOutboxEntry", fn value ->
          Value.enum!(value, @allowed_staleness_modes, "Citadel.ActionOutboxEntry.staleness_mode")
        end),
      staleness_requirements:
        Value.optional(attrs, :staleness_requirements, "Citadel.ActionOutboxEntry", fn value ->
          Value.module!(value, StalenessRequirements, "Citadel.ActionOutboxEntry.staleness_requirements")
        end, nil),
      extensions:
        Value.optional(attrs, :extensions, "Citadel.ActionOutboxEntry", fn value ->
          Value.json_object!(value, "Citadel.ActionOutboxEntry.extensions")
        end, %{})
    }

    validate_staleness_mode!(entry)
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
      durable_receipt_ref: entry.durable_receipt_ref,
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

  def replayable?(%__MODULE__{replay_status: status}) when status in [:pending, :dispatched], do: true
  def replayable?(%__MODULE__{}), do: false

  defp validate_staleness_mode!(%__MODULE__{staleness_mode: :requires_check, staleness_requirements: nil}) do
    raise ArgumentError,
          "Citadel.ActionOutboxEntry requires explicit staleness_requirements when staleness_mode is :requires_check"
  end

  defp validate_staleness_mode!(%__MODULE__{staleness_mode: :stale_exempt, staleness_requirements: %StalenessRequirements{}}) do
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

defmodule Citadel.SessionOutbox do
  @moduledoc """
  Live in-memory session outbox working set with explicit one-to-one invariants.
  """

  alias Citadel.ActionOutboxEntry
  alias Citadel.ContractCore.Value

  @schema [
    entry_order: {:list, :string},
    entries_by_id: {:map, {:struct, ActionOutboxEntry}},
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          entry_order: [String.t()],
          entries_by_id: %{required(String.t()) => ActionOutboxEntry.t()},
          extensions: map()
        }

  @enforce_keys @fields
  defstruct @fields

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.SessionOutbox", @fields)

    outbox = %__MODULE__{
      entry_order:
        Value.required(attrs, :entry_order, "Citadel.SessionOutbox", fn value ->
          Value.unique_strings!(value, "Citadel.SessionOutbox.entry_order")
        end),
      entries_by_id:
        Value.required(attrs, :entries_by_id, "Citadel.SessionOutbox", fn value ->
          Value.map_of!(value, "Citadel.SessionOutbox.entries_by_id", fn key, entry_value ->
            entry = Value.module!(entry_value, ActionOutboxEntry, "Citadel.SessionOutbox.entries_by_id[#{key}]")

            if entry.entry_id != key do
              raise ArgumentError,
                    "Citadel.SessionOutbox.entries_by_id key #{inspect(key)} does not match entry.entry_id #{inspect(entry.entry_id)}"
            end

            entry
          end)
        end),
      extensions:
        Value.optional(attrs, :extensions, "Citadel.SessionOutbox", fn value ->
          Value.json_object!(value, "Citadel.SessionOutbox.extensions")
        end, %{})
    }

    ensure_invariant!(outbox)
  end

  def dump(%__MODULE__{} = outbox) do
    %{
      entry_order: outbox.entry_order,
      entries_by_id: Map.new(outbox.entries_by_id, fn {id, entry} -> {id, ActionOutboxEntry.dump(entry)} end),
      extensions: outbox.extensions
    }
  end

  def ensure_invariant!(%__MODULE__{} = outbox) do
    order_ids = outbox.entry_order
    map_ids = outbox.entries_by_id |> Map.keys() |> Enum.sort()
    ordered_sorted = Enum.sort(order_ids)

    cond do
      ordered_sorted != map_ids ->
        raise ArgumentError,
              "Citadel.SessionOutbox invariant requires entry_order and entries_by_id to contain the same ids"

      Enum.uniq(order_ids) != order_ids ->
        raise ArgumentError,
              "Citadel.SessionOutbox.entry_order must contain each entry_id exactly once"

      true ->
        outbox
    end
  end

  def invariant?(%__MODULE__{} = outbox) do
    ensure_invariant!(outbox)
    true
  rescue
    ArgumentError -> false
  end

  def from_entries!(entries, extensions \\ %{}) do
    entries =
      Value.list!(entries, "Citadel.SessionOutbox.from_entries!", fn entry ->
        Value.module!(entry, ActionOutboxEntry, "Citadel.SessionOutbox.from_entries!")
      end)

    new!(%{
      entry_order: Enum.map(entries, & &1.entry_id),
      entries_by_id: Map.new(entries, fn entry -> {entry.entry_id, entry} end),
      extensions: extensions
    })
  end

  def put_entry!(%__MODULE__{} = outbox, entry) do
    entry = Value.module!(entry, ActionOutboxEntry, "Citadel.SessionOutbox.put_entry!")

    updated_order =
      if entry.entry_id in outbox.entry_order do
        outbox.entry_order
      else
        outbox.entry_order ++ [entry.entry_id]
      end

    new!(%{
      entry_order: updated_order,
      entries_by_id: Map.put(outbox.entries_by_id, entry.entry_id, entry),
      extensions: outbox.extensions
    })
  end

  def delete_entry!(%__MODULE__{} = outbox, entry_id) do
    entry_id = Value.string!(entry_id, "Citadel.SessionOutbox.delete_entry! entry_id")

    new!(%{
      entry_order: Enum.reject(outbox.entry_order, &(&1 == entry_id)),
      entries_by_id: Map.delete(outbox.entries_by_id, entry_id),
      extensions: outbox.extensions
    })
  end
end

defmodule Citadel.SessionState do
  @moduledoc """
  Live mutable session state reconstructed from persisted continuity plus local visibility.
  """

  alias Citadel.AuthorityDecision
  alias Citadel.BoundaryLeaseView
  alias Citadel.ContractCore.Value
  alias Citadel.DecisionRejection
  alias Citadel.Plan
  alias Citadel.ProjectBinding
  alias Citadel.ScopeRef
  alias Citadel.ServiceDescriptor
  alias Citadel.SessionOutbox

  @allowed_lifecycle_statuses [
    :active,
    :idle,
    :completed,
    :abandoned,
    :reclaiming,
    :evicted,
    :resume_pending,
    :resume_failed,
    :blocked,
    :quarantined
  ]
  @schema [
    session_id: :string,
    continuity_revision: :non_neg_integer,
    owner_incarnation: :positive_integer,
    project_binding: {:struct, ProjectBinding},
    scope_ref: {:struct, ScopeRef},
    signal_cursor: :string,
    recent_signal_hashes: {:list, :string},
    last_active_at: :datetime,
    lifecycle_status: {:enum, @allowed_lifecycle_statuses},
    active_plan: {:struct, Plan},
    active_authority_decision: {:struct, AuthorityDecision},
    last_rejection: {:struct, DecisionRejection},
    visible_services: {:list, {:struct, ServiceDescriptor}},
    boundary_lease_view: {:struct, BoundaryLeaseView},
    outbox: {:struct, SessionOutbox},
    external_refs: {:map, :json},
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type lifecycle_status ::
          :active
          | :idle
          | :completed
          | :abandoned
          | :reclaiming
          | :evicted
          | :resume_pending
          | :resume_failed
          | :blocked
          | :quarantined

  @type t :: %__MODULE__{
          session_id: String.t(),
          continuity_revision: non_neg_integer(),
          owner_incarnation: pos_integer(),
          project_binding: ProjectBinding.t() | nil,
          scope_ref: ScopeRef.t() | nil,
          signal_cursor: String.t() | nil,
          recent_signal_hashes: [String.t()],
          last_active_at: DateTime.t() | nil,
          lifecycle_status: lifecycle_status(),
          active_plan: Plan.t() | nil,
          active_authority_decision: AuthorityDecision.t() | nil,
          last_rejection: DecisionRejection.t() | nil,
          visible_services: [ServiceDescriptor.t()],
          boundary_lease_view: BoundaryLeaseView.t() | nil,
          outbox: SessionOutbox.t(),
          external_refs: map(),
          extensions: map()
        }

  @enforce_keys [:session_id, :continuity_revision, :owner_incarnation, :lifecycle_status, :outbox]
  defstruct session_id: nil,
            continuity_revision: 0,
            owner_incarnation: 1,
            project_binding: nil,
            scope_ref: nil,
            signal_cursor: nil,
            recent_signal_hashes: [],
            last_active_at: nil,
            lifecycle_status: :active,
            active_plan: nil,
            active_authority_decision: nil,
            last_rejection: nil,
            visible_services: [],
            boundary_lease_view: nil,
            outbox: nil,
            external_refs: %{},
            extensions: %{}

  def schema, do: @schema
  def allowed_lifecycle_statuses, do: @allowed_lifecycle_statuses

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.SessionState", @fields)

    %__MODULE__{
      session_id:
        Value.required(attrs, :session_id, "Citadel.SessionState", fn value ->
          Value.string!(value, "Citadel.SessionState.session_id")
        end),
      continuity_revision:
        Value.required(attrs, :continuity_revision, "Citadel.SessionState", fn value ->
          Value.non_neg_integer!(value, "Citadel.SessionState.continuity_revision")
        end),
      owner_incarnation:
        Value.required(attrs, :owner_incarnation, "Citadel.SessionState", fn value ->
          Value.positive_integer!(value, "Citadel.SessionState.owner_incarnation")
        end),
      project_binding:
        Value.optional(attrs, :project_binding, "Citadel.SessionState", fn value ->
          Value.module!(value, ProjectBinding, "Citadel.SessionState.project_binding")
        end, nil),
      scope_ref:
        Value.optional(attrs, :scope_ref, "Citadel.SessionState", fn value ->
          Value.module!(value, ScopeRef, "Citadel.SessionState.scope_ref")
        end, nil),
      signal_cursor:
        Value.optional(attrs, :signal_cursor, "Citadel.SessionState", fn value ->
          Value.string!(value, "Citadel.SessionState.signal_cursor")
        end, nil),
      recent_signal_hashes:
        Value.optional(attrs, :recent_signal_hashes, "Citadel.SessionState", fn value ->
          Value.unique_strings!(value, "Citadel.SessionState.recent_signal_hashes")
        end, []),
      last_active_at:
        Value.optional(attrs, :last_active_at, "Citadel.SessionState", fn value ->
          Value.datetime!(value, "Citadel.SessionState.last_active_at")
        end, nil),
      lifecycle_status:
        Value.required(attrs, :lifecycle_status, "Citadel.SessionState", fn value ->
          Value.enum!(value, @allowed_lifecycle_statuses, "Citadel.SessionState.lifecycle_status")
        end),
      active_plan:
        Value.optional(attrs, :active_plan, "Citadel.SessionState", fn value ->
          Value.module!(value, Plan, "Citadel.SessionState.active_plan")
        end, nil),
      active_authority_decision:
        Value.optional(attrs, :active_authority_decision, "Citadel.SessionState", fn value ->
          Value.module!(value, AuthorityDecision, "Citadel.SessionState.active_authority_decision")
        end, nil),
      last_rejection:
        Value.optional(attrs, :last_rejection, "Citadel.SessionState", fn value ->
          Value.module!(value, DecisionRejection, "Citadel.SessionState.last_rejection")
        end, nil),
      visible_services:
        Value.optional(attrs, :visible_services, "Citadel.SessionState", fn value ->
          Value.list!(value, "Citadel.SessionState.visible_services", fn item ->
            Value.module!(item, ServiceDescriptor, "Citadel.SessionState.visible_services")
          end)
        end, []),
      boundary_lease_view:
        Value.optional(attrs, :boundary_lease_view, "Citadel.SessionState", fn value ->
          Value.module!(value, BoundaryLeaseView, "Citadel.SessionState.boundary_lease_view")
        end, nil),
      outbox:
        Value.required(attrs, :outbox, "Citadel.SessionState", fn value ->
          Value.module!(value, SessionOutbox, "Citadel.SessionState.outbox")
        end),
      external_refs:
        Value.optional(attrs, :external_refs, "Citadel.SessionState", fn value ->
          Value.json_object!(value, "Citadel.SessionState.external_refs")
        end, %{}),
      extensions:
        Value.optional(attrs, :extensions, "Citadel.SessionState", fn value ->
          Value.json_object!(value, "Citadel.SessionState.extensions")
        end, %{})
    }
  end

  def dump(%__MODULE__{} = state) do
    %{
      session_id: state.session_id,
      continuity_revision: state.continuity_revision,
      owner_incarnation: state.owner_incarnation,
      project_binding: maybe_dump(state.project_binding),
      scope_ref: maybe_dump(state.scope_ref),
      signal_cursor: state.signal_cursor,
      recent_signal_hashes: state.recent_signal_hashes,
      last_active_at: state.last_active_at,
      lifecycle_status: state.lifecycle_status,
      active_plan: maybe_dump(state.active_plan),
      active_authority_decision: maybe_dump(state.active_authority_decision),
      last_rejection: maybe_dump(state.last_rejection),
      visible_services: Enum.map(state.visible_services, &ServiceDescriptor.dump/1),
      boundary_lease_view: maybe_dump(state.boundary_lease_view),
      outbox: SessionOutbox.dump(state.outbox),
      external_refs: state.external_refs,
      extensions: state.extensions
    }
  end

  defp maybe_dump(nil), do: nil
  defp maybe_dump(%module{} = struct), do: module.dump(struct)
end

defmodule Citadel.PersistedSessionEnvelope do
  @moduledoc """
  Versioned durable session continuity envelope.
  """

  alias Citadel.AuthorityDecision
  alias Citadel.ContractCore.Value
  alias Citadel.DecisionRejection
  alias Citadel.Plan
  alias Citadel.ProjectBinding
  alias Citadel.ScopeRef
  alias Citadel.SessionState

  @schema_version 1
  @fields [
    :schema_version,
    :session_id,
    :continuity_revision,
    :owner_incarnation,
    :project_binding,
    :scope_ref,
    :signal_cursor,
    :recent_signal_hashes,
    :lifecycle_status,
    :last_active_at,
    :active_plan,
    :active_authority_decision,
    :last_rejection,
    :boundary_ref,
    :outbox_entry_ids,
    :external_refs,
    :extensions
  ]

  @type t :: %__MODULE__{
          schema_version: pos_integer(),
          session_id: String.t(),
          continuity_revision: non_neg_integer(),
          owner_incarnation: pos_integer(),
          project_binding: ProjectBinding.t() | nil,
          scope_ref: ScopeRef.t() | nil,
          signal_cursor: String.t() | nil,
          recent_signal_hashes: [String.t()],
          lifecycle_status: SessionState.lifecycle_status(),
          last_active_at: DateTime.t() | nil,
          active_plan: Plan.t() | nil,
          active_authority_decision: AuthorityDecision.t() | nil,
          last_rejection: DecisionRejection.t() | nil,
          boundary_ref: String.t() | nil,
          outbox_entry_ids: [String.t()],
          external_refs: map(),
          extensions: map()
        }

  @enforce_keys [
    :schema_version,
    :session_id,
    :continuity_revision,
    :owner_incarnation,
    :lifecycle_status,
    :outbox_entry_ids
  ]
  defstruct schema_version: @schema_version,
            session_id: nil,
            continuity_revision: 0,
            owner_incarnation: 1,
            project_binding: nil,
            scope_ref: nil,
            signal_cursor: nil,
            recent_signal_hashes: [],
            lifecycle_status: :active,
            last_active_at: nil,
            active_plan: nil,
            active_authority_decision: nil,
            last_rejection: nil,
            boundary_ref: nil,
            outbox_entry_ids: [],
            external_refs: %{},
            extensions: %{}

  def schema_version, do: @schema_version

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.PersistedSessionEnvelope", @fields)

    %__MODULE__{
      schema_version:
        Value.required(attrs, :schema_version, "Citadel.PersistedSessionEnvelope", fn value ->
          if value == @schema_version do
            value
          else
            raise ArgumentError,
                  "Citadel.PersistedSessionEnvelope.schema_version must be #{@schema_version}, got: #{inspect(value)}"
          end
        end),
      session_id:
        Value.required(attrs, :session_id, "Citadel.PersistedSessionEnvelope", fn value ->
          Value.string!(value, "Citadel.PersistedSessionEnvelope.session_id")
        end),
      continuity_revision:
        Value.required(attrs, :continuity_revision, "Citadel.PersistedSessionEnvelope", fn value ->
          Value.non_neg_integer!(value, "Citadel.PersistedSessionEnvelope.continuity_revision")
        end),
      owner_incarnation:
        Value.required(attrs, :owner_incarnation, "Citadel.PersistedSessionEnvelope", fn value ->
          Value.positive_integer!(value, "Citadel.PersistedSessionEnvelope.owner_incarnation")
        end),
      project_binding:
        Value.optional(attrs, :project_binding, "Citadel.PersistedSessionEnvelope", fn value ->
          Value.module!(value, ProjectBinding, "Citadel.PersistedSessionEnvelope.project_binding")
        end, nil),
      scope_ref:
        Value.optional(attrs, :scope_ref, "Citadel.PersistedSessionEnvelope", fn value ->
          Value.module!(value, ScopeRef, "Citadel.PersistedSessionEnvelope.scope_ref")
        end, nil),
      signal_cursor:
        Value.optional(attrs, :signal_cursor, "Citadel.PersistedSessionEnvelope", fn value ->
          Value.string!(value, "Citadel.PersistedSessionEnvelope.signal_cursor")
        end, nil),
      recent_signal_hashes:
        Value.optional(attrs, :recent_signal_hashes, "Citadel.PersistedSessionEnvelope", fn value ->
          Value.unique_strings!(value, "Citadel.PersistedSessionEnvelope.recent_signal_hashes")
        end, []),
      lifecycle_status:
        Value.required(attrs, :lifecycle_status, "Citadel.PersistedSessionEnvelope", fn value ->
          Value.enum!(value, SessionState.allowed_lifecycle_statuses(), "Citadel.PersistedSessionEnvelope.lifecycle_status")
        end),
      last_active_at:
        Value.optional(attrs, :last_active_at, "Citadel.PersistedSessionEnvelope", fn value ->
          Value.datetime!(value, "Citadel.PersistedSessionEnvelope.last_active_at")
        end, nil),
      active_plan:
        Value.optional(attrs, :active_plan, "Citadel.PersistedSessionEnvelope", fn value ->
          Value.module!(value, Plan, "Citadel.PersistedSessionEnvelope.active_plan")
        end, nil),
      active_authority_decision:
        Value.optional(attrs, :active_authority_decision, "Citadel.PersistedSessionEnvelope", fn value ->
          Value.module!(value, AuthorityDecision, "Citadel.PersistedSessionEnvelope.active_authority_decision")
        end, nil),
      last_rejection:
        Value.optional(attrs, :last_rejection, "Citadel.PersistedSessionEnvelope", fn value ->
          Value.module!(value, DecisionRejection, "Citadel.PersistedSessionEnvelope.last_rejection")
        end, nil),
      boundary_ref:
        Value.optional(attrs, :boundary_ref, "Citadel.PersistedSessionEnvelope", fn value ->
          Value.string!(value, "Citadel.PersistedSessionEnvelope.boundary_ref")
        end, nil),
      outbox_entry_ids:
        Value.required(attrs, :outbox_entry_ids, "Citadel.PersistedSessionEnvelope", fn value ->
          Value.unique_strings!(value, "Citadel.PersistedSessionEnvelope.outbox_entry_ids")
        end),
      external_refs:
        Value.optional(attrs, :external_refs, "Citadel.PersistedSessionEnvelope", fn value ->
          Value.json_object!(value, "Citadel.PersistedSessionEnvelope.external_refs")
        end, %{}),
      extensions:
        Value.optional(attrs, :extensions, "Citadel.PersistedSessionEnvelope", fn value ->
          Value.json_object!(value, "Citadel.PersistedSessionEnvelope.extensions")
        end, %{})
    }
  end

  def dump(%__MODULE__{} = envelope) do
    %{
      schema_version: envelope.schema_version,
      session_id: envelope.session_id,
      continuity_revision: envelope.continuity_revision,
      owner_incarnation: envelope.owner_incarnation,
      project_binding: maybe_dump(envelope.project_binding),
      scope_ref: maybe_dump(envelope.scope_ref),
      signal_cursor: envelope.signal_cursor,
      recent_signal_hashes: envelope.recent_signal_hashes,
      lifecycle_status: envelope.lifecycle_status,
      last_active_at: envelope.last_active_at,
      active_plan: maybe_dump(envelope.active_plan),
      active_authority_decision: maybe_dump(envelope.active_authority_decision),
      last_rejection: maybe_dump(envelope.last_rejection),
      boundary_ref: envelope.boundary_ref,
      outbox_entry_ids: envelope.outbox_entry_ids,
      external_refs: envelope.external_refs,
      extensions: envelope.extensions
    }
  end

  defp maybe_dump(nil), do: nil
  defp maybe_dump(%module{} = struct), do: module.dump(struct)
end

defmodule Citadel.PersistedSessionBlob do
  @moduledoc """
  Single durable continuity write unit keyed by session id.
  """

  alias Citadel.ActionOutboxEntry
  alias Citadel.ContractCore.Value
  alias Citadel.PersistedSessionEnvelope
  alias Citadel.SessionOutbox

  @schema_version 1
  @fields [:schema_version, :session_id, :envelope, :outbox_entries, :extensions]

  @type t :: %__MODULE__{
          schema_version: pos_integer(),
          session_id: String.t(),
          envelope: PersistedSessionEnvelope.t(),
          outbox_entries: %{required(String.t()) => ActionOutboxEntry.t()},
          extensions: map()
        }

  @enforce_keys @fields
  defstruct @fields

  def schema_version, do: @schema_version

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.PersistedSessionBlob", @fields)

    blob = %__MODULE__{
      schema_version:
        Value.required(attrs, :schema_version, "Citadel.PersistedSessionBlob", fn value ->
          if value == @schema_version do
            value
          else
            raise ArgumentError,
                  "Citadel.PersistedSessionBlob.schema_version must be #{@schema_version}, got: #{inspect(value)}"
          end
        end),
      session_id:
        Value.required(attrs, :session_id, "Citadel.PersistedSessionBlob", fn value ->
          Value.string!(value, "Citadel.PersistedSessionBlob.session_id")
        end),
      envelope:
        Value.required(attrs, :envelope, "Citadel.PersistedSessionBlob", fn value ->
          Value.module!(value, PersistedSessionEnvelope, "Citadel.PersistedSessionBlob.envelope")
        end),
      outbox_entries:
        Value.required(attrs, :outbox_entries, "Citadel.PersistedSessionBlob", fn value ->
          Value.map_of!(value, "Citadel.PersistedSessionBlob.outbox_entries", fn key, entry_value ->
            entry = Value.module!(entry_value, ActionOutboxEntry, "Citadel.PersistedSessionBlob.outbox_entries[#{key}]")

            if entry.entry_id != key do
              raise ArgumentError,
                    "Citadel.PersistedSessionBlob.outbox_entries key #{inspect(key)} does not match entry.entry_id #{inspect(entry.entry_id)}"
            end

            entry
          end)
        end),
      extensions:
        Value.optional(attrs, :extensions, "Citadel.PersistedSessionBlob", fn value ->
          Value.json_object!(value, "Citadel.PersistedSessionBlob.extensions")
        end, %{})
    }

    validate_blob_invariants!(blob)
  end

  def dump(%__MODULE__{} = blob) do
    %{
      schema_version: blob.schema_version,
      session_id: blob.session_id,
      envelope: PersistedSessionEnvelope.dump(blob.envelope),
      outbox_entries:
        Map.new(blob.outbox_entries, fn {id, entry} -> {id, ActionOutboxEntry.dump(entry)} end),
      extensions: blob.extensions
    }
  end

  def restore_session_outbox!(%__MODULE__{} = blob) do
    ordered_entries =
      Enum.map(blob.envelope.outbox_entry_ids, fn entry_id ->
        case Map.fetch(blob.outbox_entries, entry_id) do
          {:ok, entry} -> entry
          :error -> raise ArgumentError, "missing outbox entry #{inspect(entry_id)} in persisted session blob"
        end
      end)

    SessionOutbox.from_entries!(ordered_entries)
  end

  defp validate_blob_invariants!(%__MODULE__{} = blob) do
    if blob.envelope.session_id != blob.session_id do
      raise ArgumentError,
            "Citadel.PersistedSessionBlob.envelope.session_id must match blob.session_id"
    end

    ordered_sorted = Enum.sort(blob.envelope.outbox_entry_ids)
    map_ids = blob.outbox_entries |> Map.keys() |> Enum.sort()

    if ordered_sorted != map_ids do
      raise ArgumentError,
            "Citadel.PersistedSessionBlob requires envelope.outbox_entry_ids to match outbox_entries"
    end

    restore_session_outbox!(blob)
    blob
  end
end

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
        Value.required(attrs, :expected_continuity_revision, "Citadel.SessionContinuityCommit", fn value ->
          Value.non_neg_integer!(value, "Citadel.SessionContinuityCommit.expected_continuity_revision")
        end),
      expected_owner_incarnation:
        Value.required(attrs, :expected_owner_incarnation, "Citadel.SessionContinuityCommit", fn value ->
          Value.positive_integer!(value, "Citadel.SessionContinuityCommit.expected_owner_incarnation")
        end),
      persisted_blob:
        Value.required(attrs, :persisted_blob, "Citadel.SessionContinuityCommit", fn value ->
          Value.module!(value, PersistedSessionBlob, "Citadel.SessionContinuityCommit.persisted_blob")
        end),
      extensions:
        Value.optional(attrs, :extensions, "Citadel.SessionContinuityCommit", fn value ->
          Value.json_object!(value, "Citadel.SessionContinuityCommit.extensions")
        end, %{})
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
