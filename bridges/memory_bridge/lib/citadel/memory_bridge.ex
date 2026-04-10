defmodule Citadel.MemoryBridge do
  @moduledoc """
  Advisory memory bridge keyed lexically by `memory_id`.
  """

  alias Citadel.BridgeCircuit
  alias Citadel.BridgeCircuitPolicy
  alias Citadel.MemoryRecord

  defmodule Downstream do
    @moduledoc false

    @callback put_memory_record(MemoryRecord.t()) ::
                {:ok, %{write_guarantee: :stable_put_by_id | :best_effort}} | {:error, atom()}

    @callback get_memory_record(String.t(), keyword()) :: {:ok, map() | nil} | {:error, atom()}

    @callback rank_memory_records(keyword()) :: {:ok, [map()]} | {:error, atom()}
  end

  @manifest %{
    package: :citadel_memory_bridge,
    layer: :bridge,
    status: :wave_5_contract_frozen,
    owns: [:advisory_memory_adapters, :lexical_put_by_id_seam, :ranked_memory_lookup],
    internal_dependencies: [:citadel_core, :citadel_runtime],
    external_dependencies: []
  }

  @type t :: %__MODULE__{
          downstream: module(),
          circuit: BridgeCircuit.t()
        }

  defstruct downstream: nil, circuit: nil

  @spec new!(keyword()) :: t()
  def new!(opts) do
    downstream = Keyword.fetch!(opts, :downstream)

    unless is_atom(downstream) and
             function_exported?(downstream, :put_memory_record, 1) and
             function_exported?(downstream, :get_memory_record, 2) and
             function_exported?(downstream, :rank_memory_records, 1) do
      raise ArgumentError,
            "Citadel.MemoryBridge.downstream must export put_memory_record/1, get_memory_record/2, and rank_memory_records/1"
    end

    %__MODULE__{
      downstream: downstream,
      circuit:
        BridgeCircuit.new!(
          policy: Keyword.get(opts, :circuit_policy, default_circuit_policy()),
          now_ms_fun: Keyword.get(opts, :now_ms_fun)
        )
    }
  end

  @spec put_memory_record(t(), MemoryRecord.t() | map() | keyword()) ::
          {:ok, %{write_guarantee: :stable_put_by_id | :best_effort}, t()} | {:error, atom(), t()}
  def put_memory_record(%__MODULE__{} = bridge, record) do
    record = MemoryRecord.new!(record)
    scope_key = scope_key(bridge.circuit.policy, record.scope_ref.scope_id)

    with_scope(bridge, scope_key, fn downstream ->
      downstream.put_memory_record(record)
    end)
  end

  @spec get_memory_record(t(), String.t(), keyword()) ::
          {:ok, MemoryRecord.t() | nil, t()} | {:error, atom(), t()}
  def get_memory_record(%__MODULE__{} = bridge, memory_id, opts \\ []) do
    memory_id = Citadel.ContractCore.Value.string!(memory_id, "Citadel.MemoryBridge memory_id")
    scope_key = scope_key(bridge.circuit.policy, Keyword.get(opts, :scope_id, "memory_read"))

    with_scope(bridge, scope_key, fn downstream ->
      case downstream.get_memory_record(memory_id, opts) do
        {:ok, nil} -> {:ok, nil}
        {:ok, raw_record} -> {:ok, MemoryRecord.new!(raw_record)}
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  @spec rank_memory_records(t(), keyword()) ::
          {:ok, [MemoryRecord.t()], t()} | {:error, atom(), t()}
  def rank_memory_records(%__MODULE__{} = bridge, opts \\ []) do
    scope_key = scope_key(bridge.circuit.policy, Keyword.get(opts, :scope_id, "memory_rank"))

    with_scope(bridge, scope_key, fn downstream ->
      case downstream.rank_memory_records(opts) do
        {:ok, records} -> {:ok, Enum.map(records, &MemoryRecord.new!/1)}
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  @spec advisory_modes() :: [atom()]
  def advisory_modes, do: [:retrieve, :upsert, :rank]

  @spec manifest() :: map()
  def manifest, do: @manifest

  @spec default_circuit_policy() :: BridgeCircuitPolicy.t()
  def default_circuit_policy do
    BridgeCircuitPolicy.new!(%{
      failure_threshold: 3,
      window_ms: 5_000,
      cooldown_ms: 10_000,
      half_open_max_inflight: 1,
      scope_key_mode: "downstream_scope",
      extensions: %{}
    })
  end

  defp with_scope(%__MODULE__{} = bridge, scope_key, fun) when is_function(fun, 1) do
    case BridgeCircuit.allow(bridge.circuit, scope_key) do
      {:ok, updated_circuit} ->
        bridge = %{bridge | circuit: updated_circuit}

        case fun.(bridge.downstream) do
          {:ok, result} ->
            {:ok, result, %{bridge | circuit: BridgeCircuit.record_success(bridge.circuit, scope_key)}}

          {:error, reason} ->
            {:error, reason, %{bridge | circuit: BridgeCircuit.record_failure(bridge.circuit, scope_key)}}
        end

      {{:error, :circuit_open}, updated_circuit} ->
        {:error, :circuit_open, %{bridge | circuit: updated_circuit}}
    end
  end

  defp scope_key(%BridgeCircuitPolicy{scope_key_mode: "bridge_global"}, _scope), do: "global"
  defp scope_key(%BridgeCircuitPolicy{scope_key_mode: "tenant_partition"}, scope), do: "tenant:#{scope}"
  defp scope_key(%BridgeCircuitPolicy{scope_key_mode: "downstream_scope"}, scope), do: "memory:#{scope}"
end
