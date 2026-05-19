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

  def new!(%__MODULE__{} = policy) do
    policy
    |> dump()
    |> new!()
  end

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
        Value.optional(
          attrs,
          :max_delay_ms,
          "Citadel.BackoffPolicy",
          fn value ->
            Value.non_neg_integer!(value, "Citadel.BackoffPolicy.max_delay_ms")
          end,
          nil
        ),
      linear_step_ms:
        Value.optional(
          attrs,
          :linear_step_ms,
          "Citadel.BackoffPolicy",
          fn value ->
            Value.non_neg_integer!(value, "Citadel.BackoffPolicy.linear_step_ms")
          end,
          nil
        ),
      multiplier:
        Value.optional(
          attrs,
          :multiplier,
          "Citadel.BackoffPolicy",
          fn value ->
            Value.positive_integer!(value, "Citadel.BackoffPolicy.multiplier")
          end,
          nil
        ),
      jitter_mode:
        Value.required(attrs, :jitter_mode, "Citadel.BackoffPolicy", fn value ->
          Value.enum!(value, @allowed_jitter_modes, "Citadel.BackoffPolicy.jitter_mode")
        end),
      jitter_window_ms:
        Value.required(attrs, :jitter_window_ms, "Citadel.BackoffPolicy", fn value ->
          Value.non_neg_integer!(value, "Citadel.BackoffPolicy.jitter_window_ms")
        end),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.BackoffPolicy",
          fn value ->
            Value.json_object!(value, "Citadel.BackoffPolicy.extensions")
          end,
          %{}
        )
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
    policy = new!(policy)
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

  defp validate_strategy_specific_requirements!(%__MODULE__{
         strategy: :linear,
         linear_step_ms: nil
       }) do
    raise ArgumentError, "Citadel.BackoffPolicy.linear_step_ms is required for linear strategy"
  end

  defp validate_strategy_specific_requirements!(%__MODULE__{
         strategy: :exponential,
         multiplier: nil
       }) do
    raise ArgumentError, "Citadel.BackoffPolicy.multiplier is required for exponential strategy"
  end

  defp validate_strategy_specific_requirements!(%__MODULE__{
         strategy: :exponential,
         multiplier: 1
       }) do
    raise ArgumentError,
          "Citadel.BackoffPolicy.multiplier must be greater than 1 for exponential strategy"
  end

  defp validate_strategy_specific_requirements!(policy), do: policy
end
