defmodule Citadel.Kernel.SessionDirectory.StoreOwner do
  @moduledoc """
  Supervised in-memory owner for `SessionDirectory` continuity stores.

  `SessionDirectory` keeps the hot working copy in its own GenServer state.
  This owner preserves committed stores across directory restarts without using
  VM-global mutable storage.
  """

  use GenServer

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def fetch(owner, store_key, default) do
    GenServer.call(owner, {:fetch, store_key, default})
  end

  def fetch!(owner, store_key, default) do
    case fetch(owner, store_key, default) do
      {:ok, store} -> store
      {:error, reason} -> raise "SessionDirectory store owner unavailable: #{inspect(reason)}"
    end
  end

  def put!(owner, store_key, store) do
    case GenServer.call(owner, {:put, store_key, store}) do
      :ok -> :ok
      {:error, reason} -> raise "SessionDirectory store owner unavailable: #{inspect(reason)}"
    end
  end

  @impl true
  def init(_opts) do
    {:ok, %{stores: %{}}}
  end

  @impl true
  def handle_call({:fetch, store_key, default}, _from, state) do
    {:reply, {:ok, Map.get(state.stores, store_key, default)}, state}
  end

  def handle_call({:put, store_key, store}, _from, state) do
    {:reply, :ok, put_in(state.stores[store_key], store)}
  end
end
