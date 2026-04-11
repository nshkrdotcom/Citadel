defmodule Citadel.Runtime.ScopeCatalog do
  @moduledoc """
  Host-local scope and target visibility owner.
  """

  use GenServer

  alias Citadel.KernelEpochUpdate
  alias Citadel.Runtime.KernelSnapshot
  alias Citadel.Runtime.SystemClock
  alias Citadel.ScopeRef
  alias Citadel.TargetResolution

  @flush_message :flush_epoch_update

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def register_scope(server \\ __MODULE__, %ScopeRef{} = scope_ref) do
    GenServer.call(server, {:register_scope, scope_ref})
  end

  def retire_scope(server \\ __MODULE__, scope_id) do
    GenServer.call(server, {:retire_scope, scope_id})
  end

  def put_target_resolution(server \\ __MODULE__, scope_id, %TargetResolution{} = resolution) do
    GenServer.call(server, {:put_target_resolution, scope_id, resolution})
  end

  def resolve_scope(server \\ __MODULE__, scope_id) do
    GenServer.call(server, {:resolve_scope, scope_id})
  end

  def resolve_target(server \\ __MODULE__, scope_id, target_id) do
    GenServer.call(server, {:resolve_target, scope_id, target_id})
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
       scopes: %{},
       targets_by_scope: %{},
       scope_catalog_epoch: Keyword.get(opts, :scope_catalog_epoch, 0),
       pending_epoch: nil,
       pending_updated_at: nil,
       flush_timer_ref: nil
     }}
  end

  @impl true
  def handle_call({:register_scope, %ScopeRef{} = scope_ref}, _from, state) do
    scopes = Map.put(state.scopes, scope_ref.scope_id, scope_ref)

    if scopes == state.scopes do
      {:reply, {:ok, state.scope_catalog_epoch}, state}
    else
      {:reply, {:ok, state.scope_catalog_epoch + 1}, bump_epoch(%{state | scopes: scopes})}
    end
  end

  def handle_call({:retire_scope, scope_id}, _from, state) do
    scopes = Map.delete(state.scopes, scope_id)
    targets_by_scope = Map.delete(state.targets_by_scope, scope_id)

    if scopes == state.scopes and targets_by_scope == state.targets_by_scope do
      {:reply, {:ok, state.scope_catalog_epoch}, state}
    else
      {:reply, {:ok, state.scope_catalog_epoch + 1},
       bump_epoch(%{state | scopes: scopes, targets_by_scope: targets_by_scope})}
    end
  end

  def handle_call(
        {:put_target_resolution, scope_id, %TargetResolution{} = resolution},
        _from,
        state
      ) do
    updated_targets =
      state.targets_by_scope
      |> Map.get(scope_id, %{})
      |> Map.put(resolution.target_id, resolution)

    targets_by_scope = Map.put(state.targets_by_scope, scope_id, updated_targets)

    if targets_by_scope == state.targets_by_scope do
      {:reply, {:ok, state.scope_catalog_epoch}, state}
    else
      {:reply, {:ok, state.scope_catalog_epoch + 1},
       bump_epoch(%{state | targets_by_scope: targets_by_scope})}
    end
  end

  def handle_call({:resolve_scope, scope_id}, _from, state) do
    {:reply, Map.get(state.scopes, scope_id), state}
  end

  def handle_call({:resolve_target, scope_id, target_id}, _from, state) do
    resolution =
      state.targets_by_scope
      |> Map.get(scope_id, %{})
      |> Map.get(target_id)

    {:reply, resolution, state}
  end

  def handle_call(:snapshot, _from, state) do
    {:reply,
     %{
       scopes: state.scopes,
       targets_by_scope: state.targets_by_scope,
       scope_catalog_epoch: state.scope_catalog_epoch
     }, state}
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
        constituent: :scope_catalog_epoch,
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
    |> Map.put(:scope_catalog_epoch, state.scope_catalog_epoch + 1)
    |> Map.put(:pending_epoch, state.scope_catalog_epoch + 1)
    |> Map.put(:pending_updated_at, updated_at)
    |> schedule_flush()
  end

  defp schedule_flush(%{flush_timer_ref: nil, flush_interval_ms: interval_ms} = state) do
    %{state | flush_timer_ref: Process.send_after(self(), @flush_message, interval_ms)}
  end

  defp schedule_flush(state), do: state
end
