defmodule Citadel.QueryBridgeTest do
  use ExUnit.Case, async: true

  alias Citadel.QueryBridge
  alias Jido.Integration.V2.SubjectRef

  defmodule Downstream do
    def fetch_runtime_observation(_query) do
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

    def fetch_boundary_session(_query) do
      {:ok,
       %{
         contract_version: "v1",
         boundary_session_id: "boundary-session-1",
         boundary_ref: "boundary-ref-1",
         session_id: "sess-1",
         tenant_id: "tenant-1",
         target_id: "target-1",
         boundary_class: "workspace_session",
         status: "attached",
         attach_mode: "fresh_or_reuse",
         lease_expires_at: ~U[2026-04-10 10:10:00Z],
         last_heartbeat_at: ~U[2026-04-10 10:05:00Z],
         extensions: %{}
       }}
    end
  end

  test "rehydrates runtime observations and boundary sessions through explicit adapters" do
    bridge = QueryBridge.new!(downstream: Downstream)

    assert {:ok, observation, bridge} =
             QueryBridge.fetch_runtime_observation(bridge, %{downstream_scope: "scope-1"})

    assert observation.observation_id == "obs-1"

    assert {:ok, descriptor, _bridge} =
             QueryBridge.fetch_boundary_session(bridge, %{downstream_scope: "scope-1"})

    assert descriptor.boundary_ref == "boundary-ref-1"
  end
end
