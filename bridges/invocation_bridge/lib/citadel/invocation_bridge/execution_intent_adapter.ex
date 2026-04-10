defmodule Citadel.InvocationBridge.ExecutionIntentAdapter do
  @moduledoc """
  Explicit adapter that freezes the `InvocationRequest -> ExecutionIntentEnvelope.V1`
  handoff without pretending the lower family already exists downstream.
  """

  alias Citadel.ActionOutboxEntry
  alias Citadel.ExecutionIntentEnvelope.V1, as: ExecutionIntentEnvelopeV1
  alias Citadel.HttpExecutionIntent.V1, as: HttpExecutionIntentV1
  alias Citadel.InvocationRequest
  alias Citadel.JsonRpcExecutionIntent.V1, as: JsonRpcExecutionIntentV1
  alias Citadel.ProcessExecutionIntent.V1, as: ProcessExecutionIntentV1

  @intent_modules %{
    "http" => HttpExecutionIntentV1,
    "process" => ProcessExecutionIntentV1,
    "json_rpc" => JsonRpcExecutionIntentV1
  }

  @spec project!(InvocationRequest.t(), ActionOutboxEntry.t()) :: ExecutionIntentEnvelopeV1.t()
  def project!(%InvocationRequest{} = request, %ActionOutboxEntry{} = entry) do
    citadel_extensions = Map.get(request.extensions, "citadel", %{})

    execution_intent_family =
      citadel_extensions["execution_intent_family"] ||
        request.topology_intent.routing_hints["execution_intent_family"] ||
        default_intent_family(request)

    execution_intent_module =
      case Map.fetch(@intent_modules, execution_intent_family) do
        {:ok, module} ->
          module

        :error ->
          raise ArgumentError,
                "Citadel.InvocationBridge requires execution_intent_family to be one of #{inspect(Map.keys(@intent_modules))}"
      end

    execution_intent_payload =
      citadel_extensions["execution_intent"] ||
        request.topology_intent.routing_hints["execution_intent"] ||
        %{}

    envelope_extensions =
      Map.merge(
        %{
          "causal_group_id" => entry.causal_group_id,
          "downstream_scope" =>
            request.topology_intent.routing_hints["downstream_scope"] ||
              "#{execution_intent_family}:#{request.target_id}"
        },
        Map.get(citadel_extensions, "execution_envelope", %{})
      )

    ExecutionIntentEnvelopeV1.new!(%{
      contract_version: ExecutionIntentEnvelopeV1.contract_version(),
      intent_envelope_id: "execution-intent:#{entry.entry_id}",
      entry_id: entry.entry_id,
      causal_group_id: entry.causal_group_id,
      invocation_request_id: request.invocation_request_id,
      invocation_schema_version: request.schema_version,
      request_id: request.request_id,
      session_id: request.session_id,
      tenant_id: request.tenant_id,
      trace_id: request.trace_id,
      actor_id: request.actor_id,
      target_id: request.target_id,
      target_kind: request.target_kind,
      allowed_operations: request.allowed_operations,
      authority_packet: request.authority_packet,
      boundary_intent: request.boundary_intent,
      topology_intent: request.topology_intent,
      execution_intent_family: execution_intent_family,
      execution_intent:
        execution_intent_module.new!(
          Map.put_new(execution_intent_payload, "contract_version", execution_intent_module.contract_version())
        ),
      extensions: envelope_extensions
    })
  end

  defp default_intent_family(%InvocationRequest{target_kind: "http"}), do: "http"
  defp default_intent_family(%InvocationRequest{target_kind: "json_rpc"}), do: "json_rpc"
  defp default_intent_family(_request), do: "process"
end
