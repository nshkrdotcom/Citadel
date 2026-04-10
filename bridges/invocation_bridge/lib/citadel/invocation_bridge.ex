defmodule Citadel.InvocationBridge do
  @moduledoc """
  Explicit invocation bridge that stops at `Citadel.InvocationRequest` and
  projects the lower `ExecutionIntentEnvelope.V1` handoff locally.
  """

  alias Citadel.ActionOutboxEntry
  alias Citadel.BridgeCircuit
  alias Citadel.BridgeCircuitPolicy
  alias Citadel.ExecutionIntentEnvelope.V1, as: ExecutionIntentEnvelopeV1
  alias Citadel.InvocationBridge.ExecutionIntentAdapter
  alias Citadel.InvocationRequest

  @behaviour Citadel.Ports.InvocationSink

  defmodule Downstream do
    @moduledoc false

    alias Citadel.ExecutionIntentEnvelope.V1

    @callback submit_execution_intent(V1.t()) :: {:ok, String.t()} | {:error, atom()}
  end

  @manifest %{
    package: :citadel_invocation_bridge,
    layer: :bridge,
    status: :wave_5_contract_frozen,
    owns: [:invocation_handoff, :lower_execution_projection, :idempotent_submission],
    internal_dependencies: [
      :citadel_core,
      :citadel_runtime,
      :citadel_authority_contract,
      :citadel_observability_contract
    ],
    external_dependencies: [:jido_integration_v2_contracts]
  }

  @type t :: %__MODULE__{
          downstream: module(),
          circuit: BridgeCircuit.t(),
          execution_intent_adapter: module(),
          receipts_by_entry_id: %{required(String.t()) => String.t()}
        }

  defstruct downstream: nil,
            circuit: nil,
            execution_intent_adapter: ExecutionIntentAdapter,
            receipts_by_entry_id: %{}

  @spec new!(keyword()) :: t()
  def new!(opts) do
    downstream = Keyword.fetch!(opts, :downstream)

    unless is_atom(downstream) and function_exported?(downstream, :submit_execution_intent, 1) do
      raise ArgumentError,
            "Citadel.InvocationBridge.downstream must export submit_execution_intent/1"
    end

    circuit_policy = Keyword.get(opts, :circuit_policy, default_circuit_policy())
    adapter = Keyword.get(opts, :execution_intent_adapter, ExecutionIntentAdapter)

    unless is_atom(adapter) and Code.ensure_loaded?(adapter) and
             function_exported?(adapter, :project!, 2) do
      raise ArgumentError,
            "Citadel.InvocationBridge.execution_intent_adapter must export project!/2"
    end

    %__MODULE__{
      downstream: downstream,
      circuit:
        BridgeCircuit.new!(policy: circuit_policy, now_ms_fun: Keyword.get(opts, :now_ms_fun)),
      execution_intent_adapter: adapter,
      receipts_by_entry_id: %{}
    }
  end

  @spec shared_contract_strategy() :: :citadel_invocation_request_entrypoint
  def shared_contract_strategy, do: :citadel_invocation_request_entrypoint

  @spec supported_invocation_request_schema_versions() :: [pos_integer(), ...]
  def supported_invocation_request_schema_versions, do: [InvocationRequest.schema_version()]

  @spec ensure_supported_invocation_request_schema_version!(integer()) :: integer()
  def ensure_supported_invocation_request_schema_version!(schema_version) do
    if schema_version in supported_invocation_request_schema_versions() do
      schema_version
    else
      raise ArgumentError,
            "unsupported Citadel.InvocationRequest.schema_version: #{inspect(schema_version)}"
    end
  end

  @impl true
  @spec submit_invocation(InvocationRequest.t(), ActionOutboxEntry.t()) ::
          {:ok, String.t()} | {:error, atom()}
  def submit_invocation(_request, _entry) do
    raise ArgumentError,
          "Citadel.InvocationBridge.submit_invocation/2 requires an initialized bridge instance; use submit/3"
  end

  @spec submit(
          t(),
          InvocationRequest.t() | map() | keyword(),
          ActionOutboxEntry.t() | map() | keyword()
        ) ::
          {:ok, String.t(), t()} | {:error, atom(), t()}
  def submit(%__MODULE__{} = bridge, request, entry) do
    if unsupported_schema_version?(request) do
      {:error, :unsupported_schema_version, bridge}
    else
      request = InvocationRequest.new!(request)
      entry = normalize_outbox_entry(entry)
      do_submit(bridge, request, entry)
    end
  end

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

  defp do_submit(
         %__MODULE__{} = bridge,
         %InvocationRequest{} = request,
         %ActionOutboxEntry{} = entry
       ) do
    case Map.fetch(bridge.receipts_by_entry_id, entry.entry_id) do
      {:ok, receipt_ref} ->
        {:ok, receipt_ref, bridge}

      :error ->
        envelope = bridge.execution_intent_adapter.project!(request, entry)
        scope_key = scope_key(bridge.circuit.policy, envelope)

        case BridgeCircuit.allow(bridge.circuit, scope_key) do
          {:ok, updated_circuit} ->
            bridge = %{bridge | circuit: updated_circuit}

            case bridge.downstream.submit_execution_intent(envelope) do
              {:ok, receipt_ref} when is_binary(receipt_ref) ->
                bridge =
                  bridge
                  |> Map.update!(:receipts_by_entry_id, &Map.put(&1, entry.entry_id, receipt_ref))
                  |> Map.put(:circuit, BridgeCircuit.record_success(bridge.circuit, scope_key))

                {:ok, receipt_ref, bridge}

              {:error, reason} ->
                {:error, reason,
                 %{bridge | circuit: BridgeCircuit.record_failure(bridge.circuit, scope_key)}}

              other ->
                {:error, normalize_error(other),
                 %{bridge | circuit: BridgeCircuit.record_failure(bridge.circuit, scope_key)}}
            end

          {{:error, :circuit_open}, updated_circuit} ->
            {:error, :circuit_open, %{bridge | circuit: updated_circuit}}
        end
    end
  end

  defp scope_key(%BridgeCircuitPolicy{scope_key_mode: "bridge_global"}, _envelope), do: "global"

  defp scope_key(%BridgeCircuitPolicy{scope_key_mode: "tenant_partition"}, envelope),
    do: envelope.tenant_id

  defp scope_key(
         %BridgeCircuitPolicy{scope_key_mode: "downstream_scope"},
         %ExecutionIntentEnvelopeV1{} = envelope
       ) do
    Map.get(
      envelope.extensions,
      "downstream_scope",
      "#{envelope.execution_intent_family}:#{envelope.target_id}"
    )
  end

  defp unsupported_schema_version?(%InvocationRequest{schema_version: schema_version}) do
    schema_version not in supported_invocation_request_schema_versions()
  end

  defp unsupported_schema_version?(request) when is_list(request) do
    request
    |> Map.new()
    |> unsupported_schema_version?()
  end

  defp unsupported_schema_version?(request) when is_map(request) do
    case Map.get(request, :schema_version, Map.get(request, "schema_version")) do
      schema_version when is_integer(schema_version) ->
        schema_version not in supported_invocation_request_schema_versions()

      _other ->
        false
    end
  end

  defp unsupported_schema_version?(_request), do: false

  defp normalize_outbox_entry(%ActionOutboxEntry{} = entry), do: entry
  defp normalize_outbox_entry(entry), do: ActionOutboxEntry.new!(entry)

  defp normalize_error({:error, reason}) when is_atom(reason), do: reason
  defp normalize_error(_other), do: :unknown
end
