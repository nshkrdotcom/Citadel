defmodule Citadel.Kernel.ServiceCatalog do
  @moduledoc """
  Host-local dynamic service visibility and admission owner.
  """

  use GenServer

  alias Citadel.KernelEpochUpdate
  alias Citadel.Kernel.KernelSnapshot
  alias Citadel.Kernel.SystemClock
  alias Citadel.ServiceDescriptor

  @flush_message :flush_epoch_update

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def register_service(server \\ __MODULE__, %ServiceDescriptor{} = descriptor) do
    GenServer.call(server, {:register_service, descriptor})
  end

  def update_service(server \\ __MODULE__, %ServiceDescriptor{} = descriptor) do
    GenServer.call(server, {:update_service, descriptor})
  end

  def retire_service(server \\ __MODULE__, service_id) do
    GenServer.call(server, {:retire_service, service_id})
  end

  def descriptor(server \\ __MODULE__, service_id) do
    GenServer.call(server, {:descriptor, service_id})
  end

  def visible_services(server \\ __MODULE__) do
    GenServer.call(server, :visible_services)
  end

  def snapshot(server \\ __MODULE__) do
    GenServer.call(server, :snapshot)
  end

  @impl true
  def init(opts) do
    {:ok,
     %{
       kernel_snapshot: Keyword.get(opts, :kernel_snapshot, KernelSnapshot),
       clock: Keyword.get(opts, :clock, SystemClock),
       flush_interval_ms: Keyword.get(opts, :flush_interval_ms, 10),
       descriptors: %{},
       service_admission_epoch: Keyword.get(opts, :service_admission_epoch, 0),
       pending_epoch: nil,
       pending_updated_at: nil,
       flush_timer_ref: nil
     }}
  end

  @impl true
  def handle_call({:register_service, %ServiceDescriptor{} = descriptor}, _from, state) do
    descriptors = Map.put(state.descriptors, descriptor.service_id, descriptor)

    if descriptors == state.descriptors do
      {:reply, {:ok, state.service_admission_epoch}, state}
    else
      {:reply, {:ok, state.service_admission_epoch + 1},
       bump_epoch(%{state | descriptors: descriptors})}
    end
  end

  def handle_call({:update_service, %ServiceDescriptor{} = descriptor}, _from, state) do
    descriptors = Map.put(state.descriptors, descriptor.service_id, descriptor)

    if descriptors == state.descriptors do
      {:reply, {:ok, state.service_admission_epoch}, state}
    else
      {:reply, {:ok, state.service_admission_epoch + 1},
       bump_epoch(%{state | descriptors: descriptors})}
    end
  end

  def handle_call({:retire_service, service_id}, _from, state) do
    descriptors = Map.delete(state.descriptors, service_id)

    if descriptors == state.descriptors do
      {:reply, {:ok, state.service_admission_epoch}, state}
    else
      {:reply, {:ok, state.service_admission_epoch + 1},
       bump_epoch(%{state | descriptors: descriptors})}
    end
  end

  def handle_call({:descriptor, service_id}, _from, state) do
    {:reply, Map.get(state.descriptors, service_id), state}
  end

  def handle_call(:visible_services, _from, state) do
    services =
      state.descriptors
      |> Map.values()
      |> Enum.sort_by(& &1.service_id)

    {:reply, services, state}
  end

  def handle_call(:snapshot, _from, state) do
    {:reply,
     %{descriptors: state.descriptors, service_admission_epoch: state.service_admission_epoch},
     state}
  end

  @impl true
  def handle_info(@flush_message, %{pending_epoch: nil} = state) do
    {:noreply, %{state | flush_timer_ref: nil}}
  end

  def handle_info(@flush_message, state) do
    KernelSnapshot.publish_epoch_update(
      state.kernel_snapshot,
      KernelEpochUpdate.new!(%{
        source_owner: Atom.to_string(__MODULE__),
        constituent: :service_admission_epoch,
        epoch: state.pending_epoch,
        updated_at: state.pending_updated_at,
        extensions: %{}
      })
    )

    {:noreply,
     %{
       state
       | pending_epoch: nil,
         pending_updated_at: nil,
         flush_timer_ref: nil
     }}
  end

  defp bump_epoch(state) do
    updated_at = state.clock.utc_now()

    state
    |> Map.put(:service_admission_epoch, state.service_admission_epoch + 1)
    |> Map.put(:pending_epoch, state.service_admission_epoch + 1)
    |> Map.put(:pending_updated_at, updated_at)
    |> schedule_flush()
  end

  defp schedule_flush(%{flush_timer_ref: nil, flush_interval_ms: interval_ms} = state) do
    %{state | flush_timer_ref: Process.send_after(self(), @flush_message, interval_ms)}
  end

  defp schedule_flush(state), do: state
end
