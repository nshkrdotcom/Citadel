defmodule Citadel.ProjectionBridge do
  @moduledoc """
  Explicit northbound publication bridge for review projections and derived-state attachments.
  """

  alias Citadel.ActionOutboxEntry
  alias Citadel.BridgeCircuit
  alias Citadel.BridgeCircuitPolicy
  alias Citadel.BridgeState
  alias Citadel.ProjectionBridge.DerivedStateAttachmentAdapter
  alias Citadel.ProjectionBridge.ReviewProjectionAdapter
  alias Jido.Integration.V2.DerivedStateAttachment
  alias Jido.Integration.V2.ReviewProjection

  @behaviour Citadel.Ports.ProjectionSink

  @type downstream_metadata :: %{
          required(:entry_id) => String.t(),
          required(:payload_kind) => String.t(),
          optional(:causal_group_id) => String.t()
        }

  defmodule Downstream do
    @moduledoc false

    alias Jido.Integration.V2.DerivedStateAttachment
    alias Jido.Integration.V2.ReviewProjection

    @callback publish_review_projection(
                ReviewProjection.t(),
                Citadel.ProjectionBridge.downstream_metadata()
              ) ::
                {:ok, String.t()} | {:error, atom()}

    @callback publish_derived_state_attachment(
                DerivedStateAttachment.t(),
                Citadel.ProjectionBridge.downstream_metadata()
              ) ::
                {:ok, String.t()} | {:error, atom()}
  end

  @manifest %{
    package: :citadel_projection_bridge,
    layer: :bridge,
    status: :wave_5_contract_frozen,
    owns: [:review_publication, :derived_state_publication, :bridge_edge_adapters],
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
          review_projection_adapter: module(),
          derived_state_attachment_adapter: module()
        }

  defstruct downstream: nil,
            circuit_policy: nil,
            state_server: nil,
            review_projection_adapter: ReviewProjectionAdapter,
            derived_state_attachment_adapter: DerivedStateAttachmentAdapter

  @spec new!(keyword()) :: t()
  def new!(opts) do
    downstream = Keyword.fetch!(opts, :downstream)

    unless is_atom(downstream) and
             function_exported?(downstream, :publish_review_projection, 2) and
             function_exported?(downstream, :publish_derived_state_attachment, 2) do
      raise ArgumentError,
            "Citadel.ProjectionBridge.downstream must export publish_review_projection/2 and publish_derived_state_attachment/2"
    end

    circuit_policy = Keyword.get(opts, :circuit_policy, default_circuit_policy())
    state_name = Keyword.get(opts, :state_name)

    %__MODULE__{
      downstream: downstream,
      circuit_policy: circuit_policy,
      state_server:
        BridgeState.ensure_started!(
          circuit:
            BridgeCircuit.new!(
              policy: circuit_policy,
              now_ms_fun: Keyword.get(opts, :now_ms_fun)
            ),
          name: state_name
        ),
      review_projection_adapter:
        Keyword.get(opts, :review_projection_adapter, ReviewProjectionAdapter),
      derived_state_attachment_adapter:
        Keyword.get(opts, :derived_state_attachment_adapter, DerivedStateAttachmentAdapter)
    }
  end

  @impl true
  @spec publish_review_projection(ReviewProjection.t(), ActionOutboxEntry.t()) :: no_return()
  def publish_review_projection(_projection, _entry) do
    raise ArgumentError,
          "Citadel.ProjectionBridge.publish_review_projection/2 requires an initialized bridge instance; use publish_review_projection/3"
  end

  @impl true
  @spec publish_derived_state_attachment(DerivedStateAttachment.t(), ActionOutboxEntry.t()) ::
          no_return()
  def publish_derived_state_attachment(_attachment, _entry) do
    raise ArgumentError,
          "Citadel.ProjectionBridge.publish_derived_state_attachment/2 requires an initialized bridge instance; use publish_derived_state_attachment/3"
  end

  @spec publish_review_projection(
          t(),
          ReviewProjection.t() | Citadel.RuntimeObservation.t(),
          ActionOutboxEntry.t()
        ) :: {:ok, String.t(), t()} | {:error, atom(), t()}
  def publish_review_projection(
        %__MODULE__{} = bridge,
        projection_or_observation,
        %ActionOutboxEntry{} = entry
      ) do
    projection = bridge.review_projection_adapter.normalize!(projection_or_observation)

    publish(
      bridge,
      entry,
      projection,
      fn downstream, payload, metadata ->
        downstream.publish_review_projection(payload, metadata)
      end,
      "review_projection"
    )
  end

  @spec publish_derived_state_attachment(
          t(),
          DerivedStateAttachment.t(),
          ActionOutboxEntry.t()
        ) :: {:ok, String.t(), t()} | {:error, atom(), t()}
  def publish_derived_state_attachment(
        %__MODULE__{} = bridge,
        %DerivedStateAttachment{} = attachment,
        %ActionOutboxEntry{} = entry
      ) do
    attachment = bridge.derived_state_attachment_adapter.normalize!(attachment)

    publish(
      bridge,
      entry,
      attachment,
      fn downstream, payload, metadata ->
        downstream.publish_derived_state_attachment(payload, metadata)
      end,
      "derived_state_attachment"
    )
  end

  @spec manifest() :: map()
  def manifest, do: @manifest

  @spec shared_contract_strategy() :: :bridge_edge_adapters
  def shared_contract_strategy, do: :bridge_edge_adapters

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

  defp publish(
         %__MODULE__{} = bridge,
         %ActionOutboxEntry{} = entry,
         payload,
         publish_fun,
         payload_kind
       )
       when is_function(publish_fun, 3) do
    scope_key = scope_key(bridge.circuit_policy, payload, payload_kind)

    case BridgeState.begin_operation(bridge.state_server, scope_key, dedupe_key: entry.entry_id) do
      {:duplicate, receipt_ref} ->
        {:ok, receipt_ref, bridge}

      {:error, reason} ->
        {:error, reason, bridge}

      {:ok, token} ->
        metadata = %{
          entry_id: entry.entry_id,
          causal_group_id: entry.causal_group_id,
          payload_kind: payload_kind
        }

        case publish_fun.(bridge.downstream, payload, metadata) do
          {:ok, receipt_ref} when is_binary(receipt_ref) ->
            {:ok, receipt_ref} =
              BridgeState.finish_operation(bridge.state_server, token, {:ok, receipt_ref})

            {:ok, receipt_ref, bridge}

          {:error, reason} ->
            {:error, reason} =
              BridgeState.finish_operation(bridge.state_server, token, {:error, reason})

            {:error, reason, bridge}

          _other ->
            {:error, :unknown} =
              BridgeState.finish_operation(bridge.state_server, token, {:error, :unknown})

            {:error, :unknown, bridge}
        end
    end
  end

  defp scope_key(%BridgeCircuitPolicy{scope_key_mode: "bridge_global"}, _payload, _payload_kind),
    do: "global"

  defp scope_key(%BridgeCircuitPolicy{scope_key_mode: "tenant_partition"}, payload, payload_kind) do
    case payload do
      %ReviewProjection{subject: subject} -> "tenant:#{subject.id}"
      %DerivedStateAttachment{subject: subject} -> "tenant:#{subject.id}"
      _ -> payload_kind
    end
  end

  defp scope_key(%BridgeCircuitPolicy{scope_key_mode: "downstream_scope"}, payload, payload_kind) do
    case payload do
      %ReviewProjection{packet_ref: packet_ref} -> "#{payload_kind}:#{packet_ref}"
      %DerivedStateAttachment{subject: subject} -> "#{payload_kind}:#{subject.id}"
      _ -> payload_kind
    end
  end
end
