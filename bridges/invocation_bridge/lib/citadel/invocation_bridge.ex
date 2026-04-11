defmodule Citadel.InvocationBridge do
  @moduledoc """
  Explicit invocation bridge that stops at `Citadel.InvocationRequest` and
  projects the lower `ExecutionIntentEnvelope.V1` handoff locally.
  """

  alias Citadel.ActionOutboxEntry
  alias Citadel.BridgeCircuit
  alias Citadel.BridgeCircuitPolicy
  alias Citadel.BridgeState
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
          circuit_policy: BridgeCircuitPolicy.t(),
          state_server: GenServer.server(),
          execution_intent_adapter: module(),
          supported_invocation_request_schema_versions: [pos_integer(), ...]
        }

  defstruct downstream: nil,
            circuit_policy: nil,
            state_server: nil,
            execution_intent_adapter: ExecutionIntentAdapter,
            supported_invocation_request_schema_versions: []

  @spec new!(keyword()) :: t()
  def new!(opts) do
    downstream = Keyword.fetch!(opts, :downstream)

    unless is_atom(downstream) and function_exported?(downstream, :submit_execution_intent, 1) do
      raise ArgumentError,
            "Citadel.InvocationBridge.downstream must export submit_execution_intent/1"
    end

    circuit_policy = Keyword.get(opts, :circuit_policy, default_circuit_policy())
    adapter = Keyword.get(opts, :execution_intent_adapter, ExecutionIntentAdapter)
    state_name = Keyword.get(opts, :state_name)

    supported_versions =
      opts
      |> Keyword.get(
        :supported_invocation_request_schema_versions,
        supported_invocation_request_schema_versions()
      )
      |> validate_supported_invocation_request_schema_versions!()

    unless is_atom(adapter) and Code.ensure_loaded?(adapter) and
             function_exported?(adapter, :project!, 2) do
      raise ArgumentError,
            "Citadel.InvocationBridge.execution_intent_adapter must export project!/2"
    end

    %__MODULE__{
      downstream: downstream,
      circuit_policy: circuit_policy,
      state_server:
        BridgeState.ensure_started!(
          circuit:
            BridgeCircuit.new!(policy: circuit_policy, now_ms_fun: Keyword.get(opts, :now_ms_fun)),
          name: state_name
        ),
      execution_intent_adapter: adapter,
      supported_invocation_request_schema_versions: supported_versions
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
  @spec submit_invocation(InvocationRequest.t(), ActionOutboxEntry.t()) :: no_return()
  def submit_invocation(_request, _entry) do
    raise ArgumentError,
          "Citadel.InvocationBridge.submit_invocation/2 requires an initialized bridge instance; use submit/3"
  end

  @spec submit(
          t(),
          InvocationRequest.t(),
          ActionOutboxEntry.t()
        ) ::
          {:ok, String.t(), t()} | {:error, atom(), t()}
  def submit(%__MODULE__{} = bridge, %InvocationRequest{} = request, %ActionOutboxEntry{} = entry) do
    if unsupported_schema_version?(bridge, request) do
      {:error, :unsupported_schema_version, bridge}
    else
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
    envelope = bridge.execution_intent_adapter.project!(request, entry)
    scope_key = scope_key(bridge.circuit_policy, envelope)

    case BridgeState.begin_operation(bridge.state_server, scope_key, dedupe_key: entry.entry_id) do
      {:duplicate, receipt_ref} ->
        {:ok, receipt_ref, bridge}

      {:error, reason} ->
        {:error, reason, bridge}

      {:ok, token} ->
        case bridge.downstream.submit_execution_intent(envelope) do
          {:ok, receipt_ref} when is_binary(receipt_ref) ->
            {:ok, receipt_ref} =
              BridgeState.finish_operation(bridge.state_server, token, {:ok, receipt_ref})

            {:ok, receipt_ref, bridge}

          {:error, reason} ->
            {:error, reason} =
              BridgeState.finish_operation(bridge.state_server, token, {:error, reason})

            {:error, reason, bridge}

          other ->
            reason = normalize_error(other)

            {:error, reason} =
              BridgeState.finish_operation(bridge.state_server, token, {:error, reason})

            {:error, reason, bridge}
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

  defp unsupported_schema_version?(
         %__MODULE__{supported_invocation_request_schema_versions: supported_versions},
         %InvocationRequest{schema_version: schema_version}
       ) do
    schema_version not in supported_versions
  end

  defp normalize_error({:error, reason}) when is_atom(reason), do: reason
  defp normalize_error(_other), do: :unknown

  defp validate_supported_invocation_request_schema_versions!(versions)
       when is_list(versions) and versions != [] do
    versions
    |> Enum.each(fn version ->
      unless is_integer(version) and version > 0 do
        raise ArgumentError,
              "supported_invocation_request_schema_versions must contain positive integers, got: #{inspect(version)}"
      end
    end)

    Enum.uniq(versions)
  end

  defp validate_supported_invocation_request_schema_versions!(other) do
    raise ArgumentError,
          "supported_invocation_request_schema_versions must be a non-empty list, got: #{inspect(other)}"
  end
end
