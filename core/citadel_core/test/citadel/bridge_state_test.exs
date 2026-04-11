defmodule Citadel.BridgeStateTest do
  use ExUnit.Case, async: true

  alias Citadel.BridgeCircuit
  alias Citadel.BridgeCircuitPolicy
  alias Citadel.BridgeState

  test "deduplicates completed operations by key" do
    {:ok, server} =
      BridgeState.start_link(
        circuit:
          BridgeCircuit.new!(
            policy:
              BridgeCircuitPolicy.new!(%{
                failure_threshold: 2,
                window_ms: 5_000,
                cooldown_ms: 5_000,
                half_open_max_inflight: 1,
                scope_key_mode: "downstream_scope",
                extensions: %{}
              })
          )
      )

    assert {:ok, token} = BridgeState.begin_operation(server, "scope-a", dedupe_key: "entry-1")
    assert {:ok, "receipt-1"} = BridgeState.finish_operation(server, token, {:ok, "receipt-1"})

    assert {:duplicate, "receipt-1"} =
             BridgeState.begin_operation(server, "scope-a", dedupe_key: "entry-1")
  end

  test "records a failure when the reserved caller dies before completing the operation" do
    {:ok, server} =
      BridgeState.start_link(
        circuit:
          BridgeCircuit.new!(
            policy:
              BridgeCircuitPolicy.new!(%{
                failure_threshold: 1,
                window_ms: 5_000,
                cooldown_ms: 5_000,
                half_open_max_inflight: 1,
                scope_key_mode: "downstream_scope",
                extensions: %{}
              })
          )
      )

    parent = self()
    monitor_ref = Process.monitor(spawn(fn -> reserve_operation(server, parent) end))

    assert_receive :operation_reserved, 1_000
    assert_receive {:DOWN, ^monitor_ref, :process, _pid, :killed}, 1_000

    wait_until(fn ->
      state = :sys.get_state(server)
      BridgeCircuit.scope_state(state.circuit, "scope-a").status == :open
    end)

    assert {:error, :circuit_open} = BridgeState.begin_operation(server, "scope-a")
  end

  defp reserve_operation(server, parent) do
    assert {:ok, _token} = BridgeState.begin_operation(server, "scope-a")
    send(parent, :operation_reserved)
    Process.exit(self(), :kill)
  end

  defp wait_until(fun, attempts \\ 40)

  defp wait_until(fun, attempts) do
    if fun.() do
      :ok
    else
      do_wait_until(fun, attempts)
    end
  end

  defp do_wait_until(fun, attempts) when attempts > 0 do
    Process.sleep(10)
    wait_until(fun, attempts - 1)
  end
end
