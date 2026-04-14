defmodule Citadel.ExecutionIntentEnvelope.V2 do
  @moduledoc """
  Successor lower execution handoff with typed execution-governance carriage.
  """

  alias Citadel.AuthorityContract.AuthorityDecision.V1, as: AuthorityDecisionV1
  alias Citadel.BoundaryIntent
  alias Citadel.ContractCore.Value
  alias Citadel.ExecutionGovernance.V1, as: ExecutionGovernanceV1
  alias Citadel.ExecutionPacket.Helpers
  alias Citadel.HttpExecutionIntent.V1, as: HttpExecutionIntentV1
  alias Citadel.JsonRpcExecutionIntent.V1, as: JsonRpcExecutionIntentV1
  alias Citadel.ProcessExecutionIntent.V1, as: ProcessExecutionIntentV1
  alias Citadel.TopologyIntent

  @contract_version "v2"
  @intent_families %{
    "http" => HttpExecutionIntentV1,
    "process" => ProcessExecutionIntentV1,
    "json_rpc" => JsonRpcExecutionIntentV1
  }
  @fields [
    :contract_version,
    :intent_envelope_id,
    :entry_id,
    :causal_group_id,
    :invocation_request_id,
    :invocation_schema_version,
    :request_id,
    :session_id,
    :tenant_id,
    :trace_id,
    :actor_id,
    :target_id,
    :target_kind,
    :allowed_operations,
    :authority_packet,
    :boundary_intent,
    :topology_intent,
    :execution_governance,
    :execution_intent_family,
    :execution_intent,
    :extensions
  ]

  @type execution_intent_t ::
          HttpExecutionIntentV1.t() | ProcessExecutionIntentV1.t() | JsonRpcExecutionIntentV1.t()

  @type t :: %__MODULE__{
          contract_version: String.t(),
          intent_envelope_id: String.t(),
          entry_id: String.t(),
          causal_group_id: String.t(),
          invocation_request_id: String.t(),
          invocation_schema_version: pos_integer(),
          request_id: String.t(),
          session_id: String.t(),
          tenant_id: String.t(),
          trace_id: String.t(),
          actor_id: String.t(),
          target_id: String.t(),
          target_kind: String.t(),
          allowed_operations: [String.t()],
          authority_packet: AuthorityDecisionV1.t(),
          boundary_intent: BoundaryIntent.t(),
          topology_intent: TopologyIntent.t(),
          execution_governance: ExecutionGovernanceV1.t(),
          execution_intent_family: String.t(),
          execution_intent: execution_intent_t(),
          extensions: map()
        }

  @enforce_keys @fields
  defstruct @fields

  def contract_version, do: @contract_version
  def intent_families, do: Map.keys(@intent_families)

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.ExecutionIntentEnvelope.V2", @fields)

    execution_intent_family =
      Helpers.required_string(
        attrs,
        :execution_intent_family,
        "Citadel.ExecutionIntentEnvelope.V2"
      )

    execution_module =
      case Map.fetch(@intent_families, execution_intent_family) do
        {:ok, module} ->
          module

        :error ->
          raise ArgumentError,
                "Citadel.ExecutionIntentEnvelope.V2.execution_intent_family must be one of #{inspect(Map.keys(@intent_families))}"
      end

    %__MODULE__{
      contract_version:
        Helpers.require_contract_version!(
          attrs,
          :contract_version,
          "Citadel.ExecutionIntentEnvelope.V2",
          @contract_version
        ),
      intent_envelope_id:
        Helpers.required_string(attrs, :intent_envelope_id, "Citadel.ExecutionIntentEnvelope.V2"),
      entry_id: Helpers.required_string(attrs, :entry_id, "Citadel.ExecutionIntentEnvelope.V2"),
      causal_group_id:
        Helpers.required_string(attrs, :causal_group_id, "Citadel.ExecutionIntentEnvelope.V2"),
      invocation_request_id:
        Helpers.required_string(
          attrs,
          :invocation_request_id,
          "Citadel.ExecutionIntentEnvelope.V2"
        ),
      invocation_schema_version:
        Helpers.required_non_neg_integer(
          attrs,
          :invocation_schema_version,
          "Citadel.ExecutionIntentEnvelope.V2"
        ),
      request_id:
        Helpers.required_string(attrs, :request_id, "Citadel.ExecutionIntentEnvelope.V2"),
      session_id:
        Helpers.required_string(attrs, :session_id, "Citadel.ExecutionIntentEnvelope.V2"),
      tenant_id: Helpers.required_string(attrs, :tenant_id, "Citadel.ExecutionIntentEnvelope.V2"),
      trace_id: Helpers.required_string(attrs, :trace_id, "Citadel.ExecutionIntentEnvelope.V2"),
      actor_id: Helpers.required_string(attrs, :actor_id, "Citadel.ExecutionIntentEnvelope.V2"),
      target_id: Helpers.required_string(attrs, :target_id, "Citadel.ExecutionIntentEnvelope.V2"),
      target_kind:
        Helpers.required_string(attrs, :target_kind, "Citadel.ExecutionIntentEnvelope.V2"),
      allowed_operations:
        Helpers.required_string_list(
          attrs,
          :allowed_operations,
          "Citadel.ExecutionIntentEnvelope.V2"
        ),
      authority_packet:
        Value.required(attrs, :authority_packet, "Citadel.ExecutionIntentEnvelope.V2", fn value ->
          Value.module!(
            value,
            AuthorityDecisionV1,
            "Citadel.ExecutionIntentEnvelope.V2.authority_packet"
          )
        end),
      boundary_intent:
        Value.required(attrs, :boundary_intent, "Citadel.ExecutionIntentEnvelope.V2", fn value ->
          Value.module!(
            value,
            BoundaryIntent,
            "Citadel.ExecutionIntentEnvelope.V2.boundary_intent"
          )
        end),
      topology_intent:
        Value.required(attrs, :topology_intent, "Citadel.ExecutionIntentEnvelope.V2", fn value ->
          Value.module!(
            value,
            TopologyIntent,
            "Citadel.ExecutionIntentEnvelope.V2.topology_intent"
          )
        end),
      execution_governance:
        Value.required(
          attrs,
          :execution_governance,
          "Citadel.ExecutionIntentEnvelope.V2",
          fn value ->
            Value.module!(
              value,
              ExecutionGovernanceV1,
              "Citadel.ExecutionIntentEnvelope.V2.execution_governance"
            )
          end
        ),
      execution_intent_family: execution_intent_family,
      execution_intent:
        Value.required(attrs, :execution_intent, "Citadel.ExecutionIntentEnvelope.V2", fn value ->
          Value.module!(
            value,
            execution_module,
            "Citadel.ExecutionIntentEnvelope.V2.execution_intent"
          )
        end),
      extensions:
        Helpers.optional_json_object(attrs, :extensions, "Citadel.ExecutionIntentEnvelope.V2")
    }
  end

  def dump(%__MODULE__{} = envelope) do
    %{
      contract_version: envelope.contract_version,
      intent_envelope_id: envelope.intent_envelope_id,
      entry_id: envelope.entry_id,
      causal_group_id: envelope.causal_group_id,
      invocation_request_id: envelope.invocation_request_id,
      invocation_schema_version: envelope.invocation_schema_version,
      request_id: envelope.request_id,
      session_id: envelope.session_id,
      tenant_id: envelope.tenant_id,
      trace_id: envelope.trace_id,
      actor_id: envelope.actor_id,
      target_id: envelope.target_id,
      target_kind: envelope.target_kind,
      allowed_operations: envelope.allowed_operations,
      authority_packet: AuthorityDecisionV1.dump(envelope.authority_packet),
      boundary_intent: BoundaryIntent.dump(envelope.boundary_intent),
      topology_intent: TopologyIntent.dump(envelope.topology_intent),
      execution_governance: ExecutionGovernanceV1.dump(envelope.execution_governance),
      execution_intent_family: envelope.execution_intent_family,
      execution_intent: dump_execution_intent(envelope.execution_intent),
      extensions: envelope.extensions
    }
  end

  defp dump_execution_intent(%HttpExecutionIntentV1{} = intent),
    do: HttpExecutionIntentV1.dump(intent)

  defp dump_execution_intent(%ProcessExecutionIntentV1{} = intent),
    do: ProcessExecutionIntentV1.dump(intent)

  defp dump_execution_intent(%JsonRpcExecutionIntentV1{} = intent),
    do: JsonRpcExecutionIntentV1.dump(intent)
end
