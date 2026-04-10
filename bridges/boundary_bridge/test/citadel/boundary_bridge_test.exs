defmodule Citadel.BoundaryBridgeTest do
  use ExUnit.Case, async: true

  alias Citadel.AttachGrant.V1, as: AttachGrantV1
  alias Citadel.BoundaryBridge
  alias Citadel.BoundaryIntent
  alias Citadel.BoundaryLeaseView

  defmodule Downstream do
    def submit_boundary_intent(projection) do
      send(Process.get(:boundary_bridge_test_pid), {:boundary_projection, projection})
      {:ok, "boundary-receipt"}
    end
  end

  setup do
    Process.put(:boundary_bridge_test_pid, self())
    :ok
  end

  test "projects boundary intent separately from signal normalization and normalizes attach-side facts" do
    bridge = BoundaryBridge.new!(downstream: Downstream)

    boundary_intent =
      BoundaryIntent.new!(%{
        boundary_class: "workspace_session",
        trust_profile: "trusted_operator",
        workspace_profile: "project_workspace",
        resource_profile: "standard",
        requested_attach_mode: "fresh_or_reuse",
        requested_ttl_ms: 30_000,
        extensions: %{}
      })

    assert {:ok, "boundary-receipt", bridge} =
             BoundaryBridge.submit_boundary_intent(bridge, boundary_intent, %{
               session_id: "sess-1",
               tenant_id: "tenant-1",
               target_id: "target-1"
             })

    assert_receive {:boundary_projection, projection}
    assert projection["boundary_intent"]["boundary_class"] == "workspace_session"

    assert {:ok, %AttachGrantV1{} = _grant, ^bridge} =
             BoundaryBridge.normalize_attach_grant(bridge, %{
               contract_version: "v1",
               attach_grant_id: "grant-1",
               boundary_session_id: "boundary-session-1",
               boundary_ref: "boundary-ref-1",
               session_id: "sess-1",
               granted_at: ~U[2026-04-10 10:00:00Z],
               expires_at: ~U[2026-04-10 10:10:00Z],
               credential_handle_refs: [],
               extensions: %{}
             })

    assert {:ok, %BoundaryLeaseView{staleness_status: :fresh}, ^bridge} =
             BoundaryBridge.normalize_boundary_lease(bridge, %{
               boundary_ref: "boundary-ref-1",
               last_heartbeat_at: ~U[2026-04-10 10:00:00Z],
               expires_at: ~U[2026-04-10 10:10:00Z],
               staleness_status: :fresh,
               lease_epoch: 1,
               extensions: %{}
             })
  end
end
