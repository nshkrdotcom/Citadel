defmodule Citadel.BoundaryBridge do
  @moduledoc """
  Explicit boundary lifecycle seam for Brain-side boundary direction and lower lifecycle facts.
  """

  alias Citadel.AttachGrant.V1, as: AttachGrantV1
  alias Citadel.BoundaryBridge.BoundaryProjectionAdapter
  alias Citadel.BoundaryIntent
  alias Citadel.BoundaryLeaseView
  alias Citadel.BoundarySessionDescriptor.V1, as: BoundarySessionDescriptorV1
  alias Citadel.BridgeCircuit
  alias Citadel.BridgeCircuitPolicy
  alias Citadel.BridgeState

  @behaviour Citadel.Ports.BoundaryLifecycle

  defmodule Downstream do
    @moduledoc false

    @callback submit_boundary_intent(
                Citadel.BoundaryBridge.BoundaryProjectionAdapter.projection()
              ) ::
                {:ok, String.t()} | {:error, atom()}
  end

  @manifest %{
    package: :citadel_boundary_bridge,
    layer: :bridge,
    status: :wave_5_contract_frozen,
    owns: [:boundary_projection, :attach_grant_normalization, :boundary_session_normalization],
    internal_dependencies: [:citadel_core, :citadel_runtime, :citadel_authority_contract],
    external_dependencies: []
  }

  @type t :: %__MODULE__{
          downstream: module(),
          circuit_policy: BridgeCircuitPolicy.t(),
          state_server: GenServer.server(),
          projection_adapter: module()
        }

  defstruct downstream: nil,
            circuit_policy: nil,
            state_server: nil,
            projection_adapter: BoundaryProjectionAdapter

  @spec new!(keyword()) :: t()
  def new!(opts) do
    downstream = Keyword.fetch!(opts, :downstream)

    unless is_atom(downstream) and function_exported?(downstream, :submit_boundary_intent, 1) do
      raise ArgumentError,
            "Citadel.BoundaryBridge.downstream must export submit_boundary_intent/1"
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
      projection_adapter: Keyword.get(opts, :projection_adapter, BoundaryProjectionAdapter)
    }
  end

  @impl true
  @spec submit_boundary_intent(
          BoundaryIntent.t(),
          Citadel.Ports.BoundaryLifecycle.boundary_intent_metadata()
        ) :: no_return()
  def submit_boundary_intent(_boundary_intent, _metadata) do
    raise ArgumentError,
          "Citadel.BoundaryBridge.submit_boundary_intent/2 requires an initialized bridge instance; use submit_boundary_intent/3"
  end

  @spec submit_boundary_intent(
          t(),
          BoundaryIntent.t(),
          Citadel.Ports.BoundaryLifecycle.boundary_intent_metadata()
        ) ::
          {:ok, String.t(), t()} | {:error, atom(), t()}
  def submit_boundary_intent(
        %__MODULE__{} = bridge,
        %BoundaryIntent{} = boundary_intent,
        metadata
      )
      when is_map(metadata) do
    projection = bridge.projection_adapter.project!(boundary_intent, metadata)
    scope_key = Map.get(projection, "downstream_scope", "boundary_lifecycle")

    case BridgeState.begin_operation(bridge.state_server, scope_key) do
      {:ok, token} ->
        case bridge.downstream.submit_boundary_intent(projection) do
          {:ok, receipt_ref} ->
            {:ok, receipt_ref} =
              BridgeState.finish_operation(bridge.state_server, token, {:ok, receipt_ref})

            {:ok, receipt_ref, bridge}

          {:error, reason} ->
            {:error, reason} =
              BridgeState.finish_operation(bridge.state_server, token, {:error, reason})

            {:error, reason, bridge}
        end

      {:error, reason} ->
        {:error, reason, bridge}
    end
  end

  @impl true
  @spec normalize_boundary_session(Citadel.Ports.BoundaryLifecycle.boundary_session_source()) ::
          no_return()
  def normalize_boundary_session(_raw_descriptor) do
    raise ArgumentError,
          "Citadel.BoundaryBridge.normalize_boundary_session/1 requires an initialized bridge instance; use normalize_boundary_session/2"
  end

  @spec normalize_boundary_session(
          t(),
          Citadel.Ports.BoundaryLifecycle.boundary_session_source()
        ) ::
          {:ok, BoundarySessionDescriptorV1.t(), t()}
  def normalize_boundary_session(%__MODULE__{} = bridge, raw_descriptor) do
    {:ok, BoundarySessionDescriptorV1.new!(raw_descriptor), bridge}
  end

  @impl true
  @spec normalize_attach_grant(Citadel.Ports.BoundaryLifecycle.attach_grant_source()) ::
          no_return()
  def normalize_attach_grant(_raw_grant) do
    raise ArgumentError,
          "Citadel.BoundaryBridge.normalize_attach_grant/1 requires an initialized bridge instance; use normalize_attach_grant/2"
  end

  @spec normalize_attach_grant(t(), Citadel.Ports.BoundaryLifecycle.attach_grant_source()) ::
          {:ok, AttachGrantV1.t(), t()}
  def normalize_attach_grant(%__MODULE__{} = bridge, raw_grant) do
    {:ok, AttachGrantV1.new!(raw_grant), bridge}
  end

  @impl true
  @spec normalize_boundary_lease(Citadel.Ports.BoundaryLifecycle.boundary_lease_source()) ::
          no_return()
  def normalize_boundary_lease(_raw_lease_view) do
    raise ArgumentError,
          "Citadel.BoundaryBridge.normalize_boundary_lease/1 requires an initialized bridge instance; use normalize_boundary_lease/2"
  end

  @spec normalize_boundary_lease(
          t(),
          Citadel.Ports.BoundaryLifecycle.boundary_lease_source()
        ) ::
          {:ok, BoundaryLeaseView.t(), t()}
  def normalize_boundary_lease(%__MODULE__{} = bridge, raw_lease_view) do
    {:ok, BoundaryLeaseView.new!(raw_lease_view), bridge}
  end

  @spec manifest() :: map()
  def manifest, do: @manifest

  @spec boundary_metadata_fields() :: [atom()]
  def boundary_metadata_fields,
    do: [:boundary_ref, :boundary_class, :attach_mode, :lease_expires_at]

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
end
