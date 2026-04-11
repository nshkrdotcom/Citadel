defmodule Citadel.BridgeCircuit do
  @moduledoc """
  Pure bridge-side circuit state keyed by the policy-selected downstream scope.
  """

  alias Citadel.BridgeCircuitPolicy
  alias Citadel.ContractCore.Value

  @type status :: :closed | :open | :half_open

  @type scope_state :: %{
          status: status(),
          failure_timestamps: [non_neg_integer()],
          opened_at_ms: non_neg_integer() | nil,
          half_open_inflight: non_neg_integer()
        }

  @type t :: %__MODULE__{
          policy: BridgeCircuitPolicy.t(),
          scope_states: %{required(String.t()) => scope_state()},
          now_ms_fun: (-> non_neg_integer())
        }

  defstruct [:policy, :scope_states, :now_ms_fun]

  @spec new!(keyword()) :: t()
  def new!(opts) do
    policy =
      opts
      |> Keyword.fetch!(:policy)
      |> Value.module!(BridgeCircuitPolicy, "Citadel.BridgeCircuit.policy")

    now_ms_fun =
      case Keyword.get(opts, :now_ms_fun) do
        nil -> fn -> System.monotonic_time(:millisecond) end
        fun -> fun
      end

    unless is_function(now_ms_fun, 0) do
      raise ArgumentError, "Citadel.BridgeCircuit.now_ms_fun must be a zero-arity function"
    end

    %__MODULE__{policy: policy, scope_states: %{}, now_ms_fun: now_ms_fun}
  end

  @spec allow(t(), String.t()) :: {:ok, t()} | {{:error, :circuit_open}, t()}
  def allow(%__MODULE__{} = circuit, scope_key) do
    scope_key = Value.string!(scope_key, "Citadel.BridgeCircuit scope_key")
    now_ms = circuit.now_ms_fun.()
    state = scope_state(circuit, scope_key)

    case state.status do
      :closed ->
        {:ok, circuit}

      :open ->
        if cooldown_elapsed?(state, circuit.policy, now_ms) do
          if state.half_open_inflight < circuit.policy.half_open_max_inflight do
            updated_state = %{
              state
              | status: :half_open,
                half_open_inflight: state.half_open_inflight + 1
            }

            {:ok, put_scope_state(circuit, scope_key, updated_state)}
          else
            {{:error, :circuit_open}, circuit}
          end
        else
          {{:error, :circuit_open}, circuit}
        end

      :half_open ->
        if state.half_open_inflight < circuit.policy.half_open_max_inflight do
          updated_state = %{state | half_open_inflight: state.half_open_inflight + 1}
          {:ok, put_scope_state(circuit, scope_key, updated_state)}
        else
          {{:error, :circuit_open}, circuit}
        end
    end
  end

  @spec record_success(t(), String.t()) :: t()
  def record_success(%__MODULE__{} = circuit, scope_key) do
    scope_key = Value.string!(scope_key, "Citadel.BridgeCircuit scope_key")
    state = scope_state(circuit, scope_key)

    put_scope_state(circuit, scope_key, %{
      state
      | status: :closed,
        failure_timestamps: [],
        opened_at_ms: nil,
        half_open_inflight: 0
    })
  end

  @spec record_failure(t(), String.t()) :: t()
  def record_failure(%__MODULE__{} = circuit, scope_key) do
    scope_key = Value.string!(scope_key, "Citadel.BridgeCircuit scope_key")
    now_ms = circuit.now_ms_fun.()
    state = scope_state(circuit, scope_key)

    next_state =
      case state.status do
        :half_open ->
          open_state(state, now_ms)

        _other ->
          failures =
            [now_ms | state.failure_timestamps]
            |> Enum.filter(&(now_ms - &1 <= circuit.policy.window_ms))

          if length(failures) >= circuit.policy.failure_threshold do
            %{open_state(state, now_ms) | failure_timestamps: failures}
          else
            %{state | status: :closed, failure_timestamps: failures}
          end
      end

    put_scope_state(circuit, scope_key, next_state)
  end

  @spec scope_state(t(), String.t()) :: scope_state()
  def scope_state(%__MODULE__{} = circuit, scope_key) do
    Map.get(circuit.scope_states, scope_key, %{
      status: :closed,
      failure_timestamps: [],
      opened_at_ms: nil,
      half_open_inflight: 0
    })
  end

  defp put_scope_state(%__MODULE__{} = circuit, scope_key, scope_state) do
    %{circuit | scope_states: Map.put(circuit.scope_states, scope_key, scope_state)}
  end

  defp open_state(state, now_ms) do
    %{
      state
      | status: :open,
        opened_at_ms: now_ms,
        half_open_inflight: 0
    }
  end

  defp cooldown_elapsed?(%{opened_at_ms: nil}, _policy, _now_ms), do: true

  defp cooldown_elapsed?(%{opened_at_ms: opened_at_ms}, policy, now_ms),
    do: now_ms - opened_at_ms >= policy.cooldown_ms
end
