defmodule Citadel.Kernel.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Citadel.Kernel.SessionRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: Citadel.Kernel.SessionSupervisor},
      {Task.Supervisor, name: Citadel.Kernel.InvocationDispatchSupervisor, max_children: 16},
      {Task.Supervisor, name: Citadel.Kernel.ProjectionDispatchSupervisor, max_children: 16},
      {Task.Supervisor, name: Citadel.Kernel.LocalDispatchSupervisor, max_children: 16},
      {Citadel.Kernel.PolicyCache,
       name: Citadel.Kernel.PolicyCache, kernel_snapshot: Citadel.Kernel.KernelSnapshot},
      {Citadel.Kernel.TopologyCatalog,
       name: Citadel.Kernel.TopologyCatalog, kernel_snapshot: Citadel.Kernel.KernelSnapshot},
      {Citadel.Kernel.KernelSnapshot, name: Citadel.Kernel.KernelSnapshot},
      {Citadel.Kernel.ScopeCatalog,
       name: Citadel.Kernel.ScopeCatalog, kernel_snapshot: Citadel.Kernel.KernelSnapshot},
      {Citadel.Kernel.ServiceCatalog,
       name: Citadel.Kernel.ServiceCatalog, kernel_snapshot: Citadel.Kernel.KernelSnapshot},
      {Citadel.Kernel.SessionDirectory,
       name: Citadel.Kernel.SessionDirectory, kernel_snapshot: Citadel.Kernel.KernelSnapshot},
      {Citadel.Kernel.BoundaryLeaseTracker,
       name: Citadel.Kernel.BoundaryLeaseTracker, kernel_snapshot: Citadel.Kernel.KernelSnapshot},
      {Citadel.Kernel.SignalIngress,
       name: Citadel.Kernel.SignalIngress,
       session_directory: Citadel.Kernel.SessionDirectory,
       signal_source: Citadel.Kernel.ObservationSignalSource,
       auto_rebuild?: false},
      {Citadel.Kernel.TracePublisher, name: Citadel.Kernel.TracePublisher}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end
end
