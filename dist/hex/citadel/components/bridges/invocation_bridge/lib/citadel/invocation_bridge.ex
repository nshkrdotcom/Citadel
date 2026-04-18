defmodule Citadel.InvocationBridge do
  @moduledoc """
  Explicit invocation bridge that stops at `Citadel.InvocationRequest.V2` and
  projects the lower `ExecutionIntentEnvelope.V2` handoff locally.
  """

  alias Citadel.ActionOutboxEntry
  alias Citadel.BridgeCircuit
  alias Citadel.BridgeCircuitPolicy
  alias Citadel.BridgeState
  alias Citadel.ExecutionIntentEnvelope.V2, as: ExecutionIntentEnvelopeV2
  alias Citadel.InvocationBridge.ExecutionIntentAdapter
  alias Citadel.InvocationRequest.V2, as: InvocationRequestV2
  alias Jido.Integration.V2.SubmissionAcceptance
  alias Jido.Integration.V2.SubmissionRejection

  defmodule Downstream do
    @moduledoc false

    alias Citadel.ExecutionIntentEnvelope.V2
    alias Jido.Integration.V2.SubmissionAcceptance
    alias Jido.Integration.V2.SubmissionRejection

    @callback submit_execution_intent(V2.t()) ::
                {:accepted, SubmissionAcceptance.t()}
                | {:rejected, SubmissionRejection.t()}
                | {:error, atom()}
  end

  @manifest %{
    package: :citadel_invocation_bridge,
    layer: :bridge,
    status: :wave_5_contract_frozen,
    owns: [:invocation_handoff, :lower_execution_projection, :idempotent_submission],
    internal_dependencies: [
      :citadel_governance,
      :citadel_kernel,
      :citadel_authority_contract,
      :citadel_execution_governance_contract,
      :citadel_observability_contract
    ],
    external_dependencies: [:jido_integration_contracts]
  }

  @type t :: %__MODULE__{
          downstream: module(),
          circuit_policy: BridgeCircuitPolicy.t(),
          state_ref: BridgeState.state_ref(),
          execution_intent_adapter: module(),
          supported_invocation_request_schema_versions: [pos_integer(), ...]
        }

  defstruct downstream: nil,
            circuit_policy: nil,
            state_ref: nil,
            execution_intent_adapter: ExecutionIntentAdapter,
            supported_invocation_request_schema_versions: []

  @spec new!(keyword()) :: t()
  def new!(opts) do
    downstream = Keyword.fetch!(opts, :downstream)

    unless is_atom(downstream) and Code.ensure_loaded?(downstream) and
             function_exported?(downstream, :submit_execution_intent, 1) do
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
      state_ref:
        BridgeState.new_ref!(
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
  def supported_invocation_request_schema_versions, do: [InvocationRequestV2.schema_version()]

  @spec ensure_supported_invocation_request_schema_version!(integer()) :: integer()
  def ensure_supported_invocation_request_schema_version!(schema_version) do
    if schema_version in supported_invocation_request_schema_versions() do
      schema_version
    else
      raise ArgumentError,
            "unsupported Citadel.InvocationRequest.V2.schema_version: #{inspect(schema_version)}"
    end
  end

  @spec submit(
          t(),
          InvocationRequestV2.t(),
          ActionOutboxEntry.t()
        ) ::
          {:accepted, SubmissionAcceptance.t(), t()}
          | {:rejected, SubmissionRejection.t(), t()}
          | {:error, atom(), t()}
  def submit(
        %__MODULE__{} = bridge,
        %InvocationRequestV2{} = request,
        %ActionOutboxEntry{} = entry
      ) do
    if unsupported_schema_version?(bridge, request) do
      {:error, :unsupported_schema_version, bridge}
    else
      do_submit(bridge, request, entry)
    end
  end

  @spec submit_invocation(
          t(),
          InvocationRequestV2.t(),
          ActionOutboxEntry.t()
        ) ::
          {:accepted, SubmissionAcceptance.t(), t()}
          | {:rejected, SubmissionRejection.t(), t()}
          | {:error, atom(), t()}
  def submit_invocation(
        %__MODULE__{} = bridge,
        %InvocationRequestV2{} = request,
        %ActionOutboxEntry{} = entry
      ) do
    submit(bridge, request, entry)
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
         %InvocationRequestV2{} = request,
         %ActionOutboxEntry{} = entry
       ) do
    envelope = bridge.execution_intent_adapter.project!(request, entry)
    scope_key = scope_key(bridge.circuit_policy, envelope)

    case BridgeState.begin_operation(bridge.state_ref, scope_key) do
      {:error, reason} ->
        {:error, reason, bridge}

      {:ok, token} ->
        case bridge.downstream.submit_execution_intent(envelope) do
          {:accepted, %SubmissionAcceptance{} = acceptance} ->
            case BridgeState.finish_operation(bridge.state_ref, token, {:accepted, acceptance}) do
              {:accepted, %SubmissionAcceptance{} = acceptance_result} ->
                {:accepted, acceptance_result, bridge}

              {:error, :operation_not_found} ->
                {:accepted, acceptance, bridge}
            end

          {:rejected, %SubmissionRejection{} = rejection} ->
            case BridgeState.finish_operation(bridge.state_ref, token, {:rejected, rejection}) do
              {:rejected, %SubmissionRejection{} = rejection_result} ->
                {:rejected, rejection_result, bridge}

              {:error, :operation_not_found} ->
                {:rejected, rejection, bridge}
            end

          {:error, reason} ->
            finish_operation_error(bridge, token, reason)

          {:ok, receipt_ref} when is_binary(receipt_ref) ->
            _ = receipt_ref
            finish_operation_error(bridge, token, :legacy_ok_result)

          other ->
            reason = normalize_error(other)
            finish_operation_error(bridge, token, reason)
        end
    end
  end

  defp scope_key(%BridgeCircuitPolicy{scope_key_mode: "bridge_global"}, _envelope), do: "global"

  defp scope_key(%BridgeCircuitPolicy{scope_key_mode: "tenant_partition"}, envelope),
    do: envelope.tenant_id

  defp scope_key(
         %BridgeCircuitPolicy{scope_key_mode: "downstream_scope"},
         %ExecutionIntentEnvelopeV2{} = envelope
       ) do
    Map.get(
      envelope.extensions,
      "downstream_scope",
      "#{envelope.execution_intent_family}:#{envelope.target_id}"
    )
  end

  defp unsupported_schema_version?(
         %__MODULE__{supported_invocation_request_schema_versions: supported_versions},
         %InvocationRequestV2{schema_version: schema_version}
       ) do
    schema_version not in supported_versions
  end

  defp finish_operation_error(bridge, token, reason) do
    case BridgeState.finish_operation(bridge.state_ref, token, {:error, reason}) do
      {:error, ^reason} -> {:error, reason, bridge}
      {:error, :operation_not_found} -> {:error, reason, bridge}
    end
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
