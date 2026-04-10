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

  defmodule Downstream do
    @moduledoc false

    @callback submit_boundary_intent(map()) :: {:ok, String.t()} | {:error, atom()}
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
          circuit: BridgeCircuit.t(),
          projection_adapter: module()
        }

  defstruct downstream: nil, circuit: nil, projection_adapter: BoundaryProjectionAdapter

  @spec new!(keyword()) :: t()
  def new!(opts) do
    downstream = Keyword.fetch!(opts, :downstream)

    unless is_atom(downstream) and function_exported?(downstream, :submit_boundary_intent, 1) do
      raise ArgumentError,
            "Citadel.BoundaryBridge.downstream must export submit_boundary_intent/1"
    end

    %__MODULE__{
      downstream: downstream,
      circuit:
        BridgeCircuit.new!(
          policy: Keyword.get(opts, :circuit_policy, default_circuit_policy()),
          now_ms_fun: Keyword.get(opts, :now_ms_fun)
        ),
      projection_adapter: Keyword.get(opts, :projection_adapter, BoundaryProjectionAdapter)
    }
  end

  @spec submit_boundary_intent(t(), BoundaryIntent.t() | map() | keyword(), map()) ::
          {:ok, String.t(), t()} | {:error, atom(), t()}
  def submit_boundary_intent(%__MODULE__{} = bridge, boundary_intent, metadata) when is_map(metadata) do
    boundary_intent = BoundaryIntent.new!(boundary_intent)
    projection = bridge.projection_adapter.project!(boundary_intent, metadata)
    scope_key = Map.get(projection, "downstream_scope", "boundary_lifecycle")

    case BridgeCircuit.allow(bridge.circuit, scope_key) do
      {:ok, updated_circuit} ->
        bridge = %{bridge | circuit: updated_circuit}

        case bridge.downstream.submit_boundary_intent(projection) do
          {:ok, receipt_ref} ->
            {:ok, receipt_ref, %{bridge | circuit: BridgeCircuit.record_success(bridge.circuit, scope_key)}}

          {:error, reason} ->
            {:error, reason, %{bridge | circuit: BridgeCircuit.record_failure(bridge.circuit, scope_key)}}
        end

      {{:error, :circuit_open}, updated_circuit} ->
        {:error, :circuit_open, %{bridge | circuit: updated_circuit}}
    end
  end

  @spec normalize_boundary_session(t(), BoundarySessionDescriptorV1.t() | map() | keyword()) ::
          {:ok, BoundarySessionDescriptorV1.t(), t()}
  def normalize_boundary_session(%__MODULE__{} = bridge, raw_descriptor) do
    {:ok, BoundarySessionDescriptorV1.new!(raw_descriptor), bridge}
  end

  @spec normalize_attach_grant(t(), AttachGrantV1.t() | map() | keyword()) ::
          {:ok, AttachGrantV1.t(), t()}
  def normalize_attach_grant(%__MODULE__{} = bridge, raw_grant) do
    {:ok, AttachGrantV1.new!(raw_grant), bridge}
  end

  @spec normalize_boundary_lease(t(), BoundaryLeaseView.t() | map() | keyword()) ::
          {:ok, BoundaryLeaseView.t(), t()}
  def normalize_boundary_lease(%__MODULE__{} = bridge, raw_lease_view) do
    {:ok, BoundaryLeaseView.new!(raw_lease_view), bridge}
  end

  @spec manifest() :: map()
  def manifest, do: @manifest

  @spec boundary_metadata_fields() :: [atom()]
  def boundary_metadata_fields, do: [:boundary_ref, :boundary_class, :attach_mode, :lease_expires_at]

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
