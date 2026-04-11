defmodule Citadel.SignalIngressRebuildPolicy do
  @moduledoc """
  Explicit rebuild policy for `SignalIngress`.
  """

  alias Citadel.ContractCore.Value

  @default_max_sessions_per_batch 64
  @default_batch_interval_ms 250
  @default_high_priority_ready_slo_ms 5_000
  @required_priority_prefix ["explicit_resume", "live_request", "pending_replay_safe"]
  @fields [
    :max_sessions_per_batch,
    :batch_interval_ms,
    :high_priority_ready_slo_ms,
    :priority_order,
    :extensions
  ]

  @type t :: %__MODULE__{
          max_sessions_per_batch: pos_integer(),
          batch_interval_ms: pos_integer(),
          high_priority_ready_slo_ms: pos_integer(),
          priority_order: [String.t()],
          extensions: map()
        }

  @enforce_keys @fields
  defstruct @fields

  def defaults do
    %{
      max_sessions_per_batch: @default_max_sessions_per_batch,
      batch_interval_ms: @default_batch_interval_ms,
      high_priority_ready_slo_ms: @default_high_priority_ready_slo_ms,
      priority_order: @required_priority_prefix ++ ["background"],
      extensions: %{}
    }
  end

  def new!(attrs) do
    attrs =
      defaults()
      |> Map.merge(Map.new(attrs))
      |> Value.normalize_attrs!("Citadel.SignalIngressRebuildPolicy", @fields)

    policy = %__MODULE__{
      max_sessions_per_batch:
        Value.required(
          attrs,
          :max_sessions_per_batch,
          "Citadel.SignalIngressRebuildPolicy",
          fn value ->
            Value.positive_integer!(
              value,
              "Citadel.SignalIngressRebuildPolicy.max_sessions_per_batch"
            )
          end
        ),
      batch_interval_ms:
        Value.required(
          attrs,
          :batch_interval_ms,
          "Citadel.SignalIngressRebuildPolicy",
          fn value ->
            Value.positive_integer!(value, "Citadel.SignalIngressRebuildPolicy.batch_interval_ms")
          end
        ),
      high_priority_ready_slo_ms:
        Value.required(
          attrs,
          :high_priority_ready_slo_ms,
          "Citadel.SignalIngressRebuildPolicy",
          fn value ->
            Value.positive_integer!(
              value,
              "Citadel.SignalIngressRebuildPolicy.high_priority_ready_slo_ms"
            )
          end
        ),
      priority_order:
        Value.required(attrs, :priority_order, "Citadel.SignalIngressRebuildPolicy", fn value ->
          Value.unique_strings!(value, "Citadel.SignalIngressRebuildPolicy.priority_order")
        end),
      extensions:
        Value.required(attrs, :extensions, "Citadel.SignalIngressRebuildPolicy", fn value ->
          Value.json_object!(value, "Citadel.SignalIngressRebuildPolicy.extensions")
        end)
    }

    validate_signal_ingress_rebuild_policy!(policy)
  end

  def dump(%__MODULE__{} = policy) do
    %{
      max_sessions_per_batch: policy.max_sessions_per_batch,
      batch_interval_ms: policy.batch_interval_ms,
      high_priority_ready_slo_ms: policy.high_priority_ready_slo_ms,
      priority_order: policy.priority_order,
      extensions: policy.extensions
    }
  end

  def priority_rank(%__MODULE__{} = policy, priority_class) when is_binary(priority_class) do
    Enum.find_index(policy.priority_order, &(&1 == priority_class)) ||
      length(policy.priority_order)
  end

  defp validate_signal_ingress_rebuild_policy!(%__MODULE__{} = policy) do
    if policy.batch_interval_ms > @default_batch_interval_ms do
      raise ArgumentError,
            "Citadel.SignalIngressRebuildPolicy.batch_interval_ms must be <= #{@default_batch_interval_ms}"
    end

    if policy.high_priority_ready_slo_ms > @default_high_priority_ready_slo_ms do
      raise ArgumentError,
            "Citadel.SignalIngressRebuildPolicy.high_priority_ready_slo_ms must be <= #{@default_high_priority_ready_slo_ms}"
    end

    if Enum.take(policy.priority_order, length(@required_priority_prefix)) !=
         @required_priority_prefix do
      raise ArgumentError,
            "Citadel.SignalIngressRebuildPolicy.priority_order must start with #{inspect(@required_priority_prefix)}"
    end

    policy
  end
end

defmodule Citadel.BoundaryResumePolicy do
  @moduledoc """
  Explicit bounded targeted boundary-classification policy for attach or resume.
  """

  alias Citadel.ContractCore.Value

  @default_max_wait_ms 30_000
  @default_retry_interval_ms 1_000
  @fields [:max_wait_ms, :retry_interval_ms, :coalesced_request_ttl_ms, :extensions]

  @type t :: %__MODULE__{
          max_wait_ms: pos_integer(),
          retry_interval_ms: pos_integer(),
          coalesced_request_ttl_ms: pos_integer(),
          extensions: map()
        }

  @enforce_keys @fields
  defstruct @fields

  def defaults do
    %{
      max_wait_ms: @default_max_wait_ms,
      retry_interval_ms: @default_retry_interval_ms,
      coalesced_request_ttl_ms: @default_retry_interval_ms,
      extensions: %{}
    }
  end

  def new!(attrs) do
    attrs =
      defaults()
      |> Map.merge(Map.new(attrs))
      |> Value.normalize_attrs!("Citadel.BoundaryResumePolicy", @fields)

    policy = %__MODULE__{
      max_wait_ms:
        Value.required(attrs, :max_wait_ms, "Citadel.BoundaryResumePolicy", fn value ->
          Value.positive_integer!(value, "Citadel.BoundaryResumePolicy.max_wait_ms")
        end),
      retry_interval_ms:
        Value.required(attrs, :retry_interval_ms, "Citadel.BoundaryResumePolicy", fn value ->
          Value.positive_integer!(value, "Citadel.BoundaryResumePolicy.retry_interval_ms")
        end),
      coalesced_request_ttl_ms:
        Value.required(
          attrs,
          :coalesced_request_ttl_ms,
          "Citadel.BoundaryResumePolicy",
          fn value ->
            Value.positive_integer!(
              value,
              "Citadel.BoundaryResumePolicy.coalesced_request_ttl_ms"
            )
          end
        ),
      extensions:
        Value.required(attrs, :extensions, "Citadel.BoundaryResumePolicy", fn value ->
          Value.json_object!(value, "Citadel.BoundaryResumePolicy.extensions")
        end)
    }

    validate_boundary_resume_policy!(policy)
  end

  def dump(%__MODULE__{} = policy) do
    %{
      max_wait_ms: policy.max_wait_ms,
      retry_interval_ms: policy.retry_interval_ms,
      coalesced_request_ttl_ms: policy.coalesced_request_ttl_ms,
      extensions: policy.extensions
    }
  end

  defp validate_boundary_resume_policy!(%__MODULE__{} = policy) do
    if policy.max_wait_ms > @default_max_wait_ms do
      raise ArgumentError,
            "Citadel.BoundaryResumePolicy.max_wait_ms must be <= #{@default_max_wait_ms}"
    end

    if policy.retry_interval_ms > @default_retry_interval_ms do
      raise ArgumentError,
            "Citadel.BoundaryResumePolicy.retry_interval_ms must be <= #{@default_retry_interval_ms}"
    end

    if policy.coalesced_request_ttl_ms > policy.max_wait_ms do
      raise ArgumentError,
            "Citadel.BoundaryResumePolicy.coalesced_request_ttl_ms must be <= max_wait_ms"
    end

    policy
  end
end

defmodule Citadel.SessionActivationPolicy do
  @moduledoc """
  Explicit bounded cold-boot or mass-recovery activation policy.
  """

  alias Citadel.ContractCore.Value

  @required_priority_prefix [
    "blocked",
    "pending_replay_safe",
    "explicit_resume",
    "committed_signal_lag"
  ]
  @fields [:max_concurrent_activations, :refill_interval_ms, :priority_order, :extensions]

  @type t :: %__MODULE__{
          max_concurrent_activations: pos_integer(),
          refill_interval_ms: pos_integer(),
          priority_order: [String.t()],
          extensions: map()
        }

  @enforce_keys @fields
  defstruct @fields

  def defaults do
    %{
      max_concurrent_activations: 4,
      refill_interval_ms: 100,
      priority_order: @required_priority_prefix ++ ["idle"],
      extensions: %{}
    }
  end

  def new!(attrs) do
    attrs =
      defaults()
      |> Map.merge(Map.new(attrs))
      |> Value.normalize_attrs!("Citadel.SessionActivationPolicy", @fields)

    policy = %__MODULE__{
      max_concurrent_activations:
        Value.required(
          attrs,
          :max_concurrent_activations,
          "Citadel.SessionActivationPolicy",
          fn value ->
            Value.positive_integer!(
              value,
              "Citadel.SessionActivationPolicy.max_concurrent_activations"
            )
          end
        ),
      refill_interval_ms:
        Value.required(attrs, :refill_interval_ms, "Citadel.SessionActivationPolicy", fn value ->
          Value.positive_integer!(value, "Citadel.SessionActivationPolicy.refill_interval_ms")
        end),
      priority_order:
        Value.required(attrs, :priority_order, "Citadel.SessionActivationPolicy", fn value ->
          Value.unique_strings!(value, "Citadel.SessionActivationPolicy.priority_order")
        end),
      extensions:
        Value.required(attrs, :extensions, "Citadel.SessionActivationPolicy", fn value ->
          Value.json_object!(value, "Citadel.SessionActivationPolicy.extensions")
        end)
    }

    validate_session_activation_policy!(policy)
  end

  def dump(%__MODULE__{} = policy) do
    %{
      max_concurrent_activations: policy.max_concurrent_activations,
      refill_interval_ms: policy.refill_interval_ms,
      priority_order: policy.priority_order,
      extensions: policy.extensions
    }
  end

  def priority_rank(%__MODULE__{} = policy, priority_class) when is_binary(priority_class) do
    Enum.find_index(policy.priority_order, &(&1 == priority_class)) ||
      length(policy.priority_order)
  end

  defp validate_session_activation_policy!(%__MODULE__{} = policy) do
    if Enum.take(policy.priority_order, length(@required_priority_prefix)) !=
         @required_priority_prefix do
      raise ArgumentError,
            "Citadel.SessionActivationPolicy.priority_order must start with #{inspect(@required_priority_prefix)}"
    end

    if Enum.member?(Enum.take(policy.priority_order, length(policy.priority_order) - 1), "idle") do
      raise ArgumentError,
            "Citadel.SessionActivationPolicy.priority_order must place idle after active recovery classes"
    end

    policy
  end
end
