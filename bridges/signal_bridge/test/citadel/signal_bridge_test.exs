defmodule Citadel.SignalBridgeTest do
  use ExUnit.Case, async: true

  alias Citadel.SignalBridge
  alias Jido.Integration.V2.SubjectRef

  defmodule Adapter do
    def normalize_signal(_raw_signal) do
      {:ok,
       %{
         observation_id: "obs-1",
         request_id: "req-1",
         session_id: "sess-1",
         signal_id: "sig-1",
         signal_cursor: "cursor-1",
         runtime_ref_id: "runtime-1",
         event_kind: "execution_event",
         event_at: ~U[2026-04-10 10:00:00Z],
         status: "ok",
         output: %{"result" => "done"},
         artifacts: [],
         payload: %{"phase" => "done"},
         subject_ref: SubjectRef.new!(%{kind: :run, id: "run-1"}),
         evidence_refs: [],
         governance_refs: [],
         extensions: %{}
       }}
    end
  end

  test "normalizes runtime signals into runtime observations" do
    bridge = SignalBridge.new!(adapter: Adapter)

    assert {:ok, observation, ^bridge} = SignalBridge.normalize_signal(bridge, %{kind: "runtime_event"})
    assert observation.signal_id == "sig-1"
  end

  test "rejects boundary lifecycle signals so boundary normalization stays in boundary bridge" do
    bridge = SignalBridge.new!(adapter: Adapter)

    assert {:error, :boundary_lifecycle_signal, ^bridge} =
             SignalBridge.normalize_signal(bridge, %{"event_kind" => "attach_grant"})
  end
end
