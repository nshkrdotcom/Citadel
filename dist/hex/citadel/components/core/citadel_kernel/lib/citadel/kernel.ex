defmodule Citadel.Kernel do
  @moduledoc """
  Packet-aligned ownership surface for `core/citadel_kernel`.
  """

  @manifest %{
    package: :citadel_kernel,
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
      :citadel_governance,
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
        {Citadel.Kernel.SessionServer, :start_link,
         [
           opts
           |> Keyword.put_new(:name, via_tuple(session_id))
           |> Keyword.put_new(:trace_publisher, Citadel.Kernel.TracePublisher)
         ]},
      restart: :transient
    }

    DynamicSupervisor.start_child(Citadel.Kernel.SessionSupervisor, child_spec)
  end

  def lookup_session(session_id) do
    case Registry.lookup(Citadel.Kernel.SessionRegistry, session_id) do
      [{pid, _value}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  def via_tuple(session_id) do
    {:via, Registry, {Citadel.Kernel.SessionRegistry, session_id}}
  end
end
