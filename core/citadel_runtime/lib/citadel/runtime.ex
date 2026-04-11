defmodule Citadel.Runtime do
  @moduledoc """
  Packet-aligned ownership surface for `core/citadel_runtime`.
  """

  @manifest %{
    package: :citadel_runtime,
    layer: :core,
    status: :wave_6_runtime_coordination,
    owns: [
      :policy_cache,
      :topology_catalog,
      :kernel_snapshot,
      :scope_catalog,
      :service_catalog,
      :session_directory,
      :boundary_lease_tracker,
      :signal_ingress,
      :trace_publisher,
      :session_runtime
    ],
    internal_dependencies: [
      :citadel_core,
      :citadel_authority_contract,
      :citadel_observability_contract
    ],
    external_dependencies: []
  }

  @spec manifest() :: map()
  def manifest, do: @manifest

  def start_session(opts) do
    session_id = Keyword.fetch!(opts, :session_id)

    child_spec = %{
      id: {:session_server, session_id},
      start:
        {Citadel.Runtime.SessionServer, :start_link,
         [Keyword.put_new(opts, :name, via_tuple(session_id))]},
      restart: :transient
    }

    DynamicSupervisor.start_child(Citadel.Runtime.SessionSupervisor, child_spec)
  end

  def lookup_session(session_id) do
    case Registry.lookup(Citadel.Runtime.SessionRegistry, session_id) do
      [{pid, _value}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  def via_tuple(session_id) do
    {:via, Registry, {Citadel.Runtime.SessionRegistry, session_id}}
  end
end
