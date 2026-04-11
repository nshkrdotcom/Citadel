defmodule Citadel.QueryBridge do
  @moduledoc """
  Rehydrates durable lower truth into normalized Citadel read models.
  """

  alias Citadel.BoundarySessionDescriptor.V1, as: BoundarySessionDescriptorV1
  alias Citadel.BridgeCircuit
  alias Citadel.BridgeCircuitPolicy
  alias Citadel.BridgeState
  alias Citadel.RuntimeObservation

  @behaviour Citadel.Ports.RuntimeQuery

  defmodule Downstream do
    @moduledoc false

    @callback fetch_runtime_observation(Citadel.Ports.RuntimeQuery.runtime_observation_query()) ::
                {:ok, map()} | {:error, atom()}
    @callback fetch_boundary_session(Citadel.Ports.RuntimeQuery.boundary_session_query()) ::
                {:ok, map()} | {:error, atom()}
  end

  @manifest %{
    package: :citadel_query_bridge,
    layer: :bridge,
    status: :wave_5_contract_frozen,
    owns: [:rehydration_adapters, :runtime_observation_normalization, :boundary_truth_rehydration],
    internal_dependencies: [:citadel_core, :citadel_runtime],
    external_dependencies: []
  }

  @type t :: %__MODULE__{
          downstream: module(),
          circuit_policy: BridgeCircuitPolicy.t(),
          state_server: GenServer.server()
        }

  defstruct downstream: nil, circuit_policy: nil, state_server: nil

  @spec new!(keyword()) :: t()
  def new!(opts) do
    downstream = Keyword.fetch!(opts, :downstream)

    unless is_atom(downstream) and
             function_exported?(downstream, :fetch_runtime_observation, 1) and
             function_exported?(downstream, :fetch_boundary_session, 1) do
      raise ArgumentError,
            "Citadel.QueryBridge.downstream must export fetch_runtime_observation/1 and fetch_boundary_session/1"
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
        )
    }
  end

  @impl true
  @spec fetch_runtime_observation(Citadel.Ports.RuntimeQuery.runtime_observation_query()) ::
          no_return()
  def fetch_runtime_observation(_query) do
    raise ArgumentError,
          "Citadel.QueryBridge.fetch_runtime_observation/1 requires an initialized bridge instance; use fetch_runtime_observation/2"
  end

  @impl true
  @spec fetch_boundary_session(Citadel.Ports.RuntimeQuery.boundary_session_query()) ::
          no_return()
  def fetch_boundary_session(_query) do
    raise ArgumentError,
          "Citadel.QueryBridge.fetch_boundary_session/1 requires an initialized bridge instance; use fetch_boundary_session/2"
  end

  @spec fetch_runtime_observation(t(), Citadel.Ports.RuntimeQuery.runtime_observation_query()) ::
          {:ok, RuntimeObservation.t(), t()} | {:error, atom(), t()}
  def fetch_runtime_observation(%__MODULE__{} = bridge, query) when is_map(query) do
    with_scope(bridge, query, fn downstream, normalized_query ->
      case downstream.fetch_runtime_observation(normalized_query) do
        {:ok, raw_observation} -> {:ok, RuntimeObservation.new!(raw_observation)}
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  @spec fetch_boundary_session(t(), Citadel.Ports.RuntimeQuery.boundary_session_query()) ::
          {:ok, BoundarySessionDescriptorV1.t(), t()} | {:error, atom(), t()}
  def fetch_boundary_session(%__MODULE__{} = bridge, query) when is_map(query) do
    with_scope(bridge, query, fn downstream, normalized_query ->
      case downstream.fetch_boundary_session(normalized_query) do
        {:ok, raw_descriptor} -> {:ok, BoundarySessionDescriptorV1.new!(raw_descriptor)}
        {:error, reason} -> {:error, reason}
      end
    end)
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

  defp with_scope(%__MODULE__{} = bridge, query, fun) when is_function(fun, 2) do
    scope_key =
      Map.get(query, "downstream_scope", Map.get(query, :downstream_scope, "runtime_query"))

    normalized_query = Map.new(query)

    case BridgeState.begin_operation(bridge.state_server, scope_key) do
      {:ok, token} ->
        case fun.(bridge.downstream, normalized_query) do
          {:ok, result} ->
            {:ok, result} =
              BridgeState.finish_operation(bridge.state_server, token, {:ok, result})

            {:ok, result, bridge}

          {:error, reason} ->
            {:error, reason} =
              BridgeState.finish_operation(bridge.state_server, token, {:error, reason})

            {:error, reason, bridge}
        end

      {:error, reason} ->
        {:error, reason, bridge}
    end
  end
end
