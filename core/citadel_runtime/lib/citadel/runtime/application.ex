defmodule Citadel.Runtime.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Citadel.Runtime.SessionRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: Citadel.Runtime.SessionSupervisor},
      {Task.Supervisor, name: Citadel.Runtime.InvocationDispatchSupervisor, max_children: 16},
      {Task.Supervisor, name: Citadel.Runtime.ProjectionDispatchSupervisor, max_children: 16},
      {Task.Supervisor, name: Citadel.Runtime.LocalDispatchSupervisor, max_children: 16},
      {Citadel.Runtime.PolicyCache, name: Citadel.Runtime.PolicyCache, kernel_snapshot: Citadel.Runtime.KernelSnapshot},
      {Citadel.Runtime.TopologyCatalog, name: Citadel.Runtime.TopologyCatalog, kernel_snapshot: Citadel.Runtime.KernelSnapshot},
      {Citadel.Runtime.KernelSnapshot, name: Citadel.Runtime.KernelSnapshot},
      {Citadel.Runtime.ScopeCatalog, name: Citadel.Runtime.ScopeCatalog, kernel_snapshot: Citadel.Runtime.KernelSnapshot},
      {Citadel.Runtime.ServiceCatalog, name: Citadel.Runtime.ServiceCatalog, kernel_snapshot: Citadel.Runtime.KernelSnapshot},
      {Citadel.Runtime.SessionDirectory, name: Citadel.Runtime.SessionDirectory, kernel_snapshot: Citadel.Runtime.KernelSnapshot},
      {Citadel.Runtime.BoundaryLeaseTracker, name: Citadel.Runtime.BoundaryLeaseTracker, kernel_snapshot: Citadel.Runtime.KernelSnapshot},
      {Citadel.Runtime.SignalIngress,
       name: Citadel.Runtime.SignalIngress,
       session_directory: Citadel.Runtime.SessionDirectory,
       signal_source: Citadel.Runtime.NoopSignalSource,
       auto_rebuild?: false},
      {Citadel.Runtime.TracePublisher, name: Citadel.Runtime.TracePublisher}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end
end
