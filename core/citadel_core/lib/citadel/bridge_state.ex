defmodule Citadel.BridgeState do
  @moduledoc """
  Process-backed owner for bridge circuit state and optional deduplication receipts.
  """

  use GenServer

  alias Citadel.BridgeCircuit
  alias Citadel.ContractCore.Value

  @type operation_token :: reference()

  @type state :: %{
          circuit: BridgeCircuit.t(),
          receipts_by_dedupe_key: %{optional(String.t()) => term()},
          pending_operations: %{optional(operation_token()) => map()},
          pending_dedupe_keys: %{optional(String.t()) => operation_token()},
          monitor_refs: %{optional(reference()) => operation_token()}
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name)
    start_opts = if is_nil(name), do: [], else: [name: name]
    GenServer.start_link(__MODULE__, opts, start_opts)
  end

  @spec ensure_started!(keyword()) :: GenServer.server()
  def ensure_started!(opts) do
    case start_link(opts) do
      {:ok, pid} ->
        pid

      {:error, {:already_started, pid}} ->
        pid

      {:error, reason} ->
        raise RuntimeError, "Citadel.BridgeState failed to start: #{inspect(reason)}"
    end
  end

  @spec begin_operation(GenServer.server(), String.t(), keyword()) ::
          {:ok, operation_token()}
          | {:duplicate, term()}
          | {:error, :circuit_open | :submission_inflight}
  def begin_operation(server, scope_key, opts \\ []) do
    dedupe_key = Keyword.get(opts, :dedupe_key)
    GenServer.call(server, {:begin_operation, scope_key, dedupe_key})
  end

  @spec finish_operation(GenServer.server(), operation_token(), {:ok, term()} | {:error, atom()}) ::
          {:ok, term()} | {:error, atom() | :operation_not_found}
  def finish_operation(server, token, result) when is_reference(token) do
    GenServer.call(server, {:finish_operation, token, result})
  end

  @impl true
  def init(opts) do
    circuit =
      opts
      |> Keyword.fetch!(:circuit)
      |> Value.module!(BridgeCircuit, "Citadel.BridgeState.circuit")

    {:ok,
     %{
       circuit: circuit,
       receipts_by_dedupe_key: %{},
       pending_operations: %{},
       pending_dedupe_keys: %{},
       monitor_refs: %{}
     }}
  end

  @impl true
  def handle_call({:begin_operation, scope_key, dedupe_key}, {caller_pid, _tag}, state) do
    scope_key = Value.string!(scope_key, "Citadel.BridgeState scope_key")
    state = validate_dedupe_key!(state, dedupe_key)

    case dedupe_reply(state, dedupe_key) do
      {:duplicate, receipt_ref} ->
        {:reply, {:duplicate, receipt_ref}, state}

      {:error, :submission_inflight} ->
        {:reply, {:error, :submission_inflight}, state}

      :proceed ->
        case BridgeCircuit.allow(state.circuit, scope_key) do
          {:ok, updated_circuit} ->
            token = make_ref()
            monitor_ref = Process.monitor(caller_pid)

            pending_operation = %{
              owner_pid: caller_pid,
              scope_key: scope_key,
              dedupe_key: dedupe_key,
              monitor_ref: monitor_ref
            }

            state =
              state
              |> Map.put(:circuit, updated_circuit)
              |> put_in([:pending_operations, token], pending_operation)
              |> put_in([:monitor_refs, monitor_ref], token)
              |> maybe_put_pending_dedupe_key(dedupe_key, token)

            {:reply, {:ok, token}, state}

          {{:error, :circuit_open}, updated_circuit} ->
            {:reply, {:error, :circuit_open}, %{state | circuit: updated_circuit}}
        end
    end
  end

  def handle_call({:finish_operation, token, result}, _from, state) do
    case Map.pop(state.pending_operations, token) do
      {nil, _pending_operations} ->
        {:reply, {:error, :operation_not_found}, state}

      {pending_operation, pending_operations} ->
        Process.demonitor(pending_operation.monitor_ref, [:flush])

        state =
          state
          |> Map.put(:pending_operations, pending_operations)
          |> update_in([:monitor_refs], &Map.delete(&1, pending_operation.monitor_ref))
          |> maybe_delete_pending_dedupe_key(pending_operation.dedupe_key)
          |> apply_operation_result(pending_operation, result)

        {:reply, result, state}
    end
  end

  @impl true
  def handle_info({:DOWN, monitor_ref, :process, _pid, _reason}, state) do
    case Map.pop(state.monitor_refs, monitor_ref) do
      {nil, _monitor_refs} ->
        {:noreply, state}

      {token, monitor_refs} ->
        {pending_operation, pending_operations} = Map.pop(state.pending_operations, token)

        state =
          state
          |> Map.put(:monitor_refs, monitor_refs)
          |> Map.put(:pending_operations, pending_operations)
          |> maybe_delete_pending_dedupe_key(pending_operation.dedupe_key)
          |> Map.update!(:circuit, &BridgeCircuit.record_failure(&1, pending_operation.scope_key))

        {:noreply, state}
    end
  end

  defp dedupe_reply(_state, nil), do: :proceed

  defp dedupe_reply(state, dedupe_key) do
    cond do
      Map.has_key?(state.receipts_by_dedupe_key, dedupe_key) ->
        {:duplicate, Map.fetch!(state.receipts_by_dedupe_key, dedupe_key)}

      Map.has_key?(state.pending_dedupe_keys, dedupe_key) ->
        {:error, :submission_inflight}

      true ->
        :proceed
    end
  end

  defp validate_dedupe_key!(state, nil), do: state

  defp validate_dedupe_key!(state, dedupe_key) do
    Value.string!(dedupe_key, "Citadel.BridgeState dedupe_key")
    state
  end

  defp maybe_put_pending_dedupe_key(state, nil, _token), do: state

  defp maybe_put_pending_dedupe_key(state, dedupe_key, token) do
    put_in(state, [:pending_dedupe_keys, dedupe_key], token)
  end

  defp maybe_delete_pending_dedupe_key(state, nil), do: state

  defp maybe_delete_pending_dedupe_key(state, dedupe_key) do
    update_in(state.pending_dedupe_keys, &Map.delete(&1, dedupe_key))
    |> then(fn pending_dedupe_keys -> %{state | pending_dedupe_keys: pending_dedupe_keys} end)
  end

  defp apply_operation_result(state, pending_operation, {:ok, result}) do
    state =
      state
      |> Map.update!(:circuit, &BridgeCircuit.record_success(&1, pending_operation.scope_key))

    case pending_operation.dedupe_key do
      nil ->
        state

      dedupe_key ->
        put_in(state, [:receipts_by_dedupe_key, dedupe_key], result)
    end
  end

  defp apply_operation_result(state, pending_operation, {:error, _reason}) do
    Map.update!(state, :circuit, &BridgeCircuit.record_failure(&1, pending_operation.scope_key))
  end
end
