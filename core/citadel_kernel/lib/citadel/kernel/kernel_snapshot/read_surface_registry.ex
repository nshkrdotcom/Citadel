defmodule Citadel.Kernel.KernelSnapshot.ReadSurfaceRegistry do
  @moduledoc """
  Supervised registry for kernel snapshot read-surface discovery.

  Snapshot values remain in owner-created ETS tables. This registry only maps
  stable read-surface keys to those tables, avoiding VM-global mutable
  discovery state.
  """

  use GenServer

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def register(registry, read_surface_key, discovery) do
    call(registry, {:register, read_surface_key, discovery})
  end

  def fetch(registry, read_surface_key) do
    call(registry, {:fetch, read_surface_key})
  end

  @impl true
  def init(_opts) do
    {:ok, %{read_surfaces: %{}}}
  end

  @impl true
  def handle_call({:register, read_surface_key, discovery}, _from, state) do
    {:reply, :ok, put_in(state.read_surfaces[read_surface_key], discovery)}
  end

  def handle_call({:fetch, read_surface_key}, _from, state) do
    {:reply, Map.fetch(state.read_surfaces, read_surface_key), state}
  end

  defp call(nil, _message), do: {:error, :read_surface_registry_disabled}

  defp call(registry, message) do
    GenServer.call(registry, message)
  catch
    :exit, _reason -> {:error, :read_surface_registry_unavailable}
  end
end
