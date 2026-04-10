defmodule Citadel.MemoryBridgeTest do
  use ExUnit.Case, async: true

  alias Citadel.MemoryBridge
  alias Citadel.MemoryRecord
  alias Citadel.ScopeRef

  defmodule Downstream do
    def put_memory_record(_record), do: {:ok, %{write_guarantee: :best_effort}}

    def get_memory_record("memory-1", _opts) do
      {:ok,
       %{
         memory_id: "memory-1",
         scope_ref:
           ScopeRef.new!(%{
             scope_id: "scope-1",
             scope_kind: "workspace",
             workspace_root: "/workspace",
             environment: "test",
             catalog_epoch: 1,
             extensions: %{}
           }),
         session_id: "sess-1",
         kind: "summary",
         summary: "Prior run state",
         subject_links: [],
         evidence_links: [],
         expires_at: nil,
         confidence: 0.9,
         metadata: %{}
       }}
    end

    def get_memory_record(_memory_id, _opts), do: {:ok, nil}

    def rank_memory_records(_opts) do
      {:ok, []}
    end
  end

  test "keeps memory advisory and keyed by explicit memory_id" do
    scope_ref =
      ScopeRef.new!(%{
        scope_id: "scope-1",
        scope_kind: "workspace",
        workspace_root: "/workspace",
        environment: "test",
        catalog_epoch: 1,
        extensions: %{}
      })

    record =
      MemoryRecord.new!(%{
        memory_id: "memory-1",
        scope_ref: scope_ref,
        session_id: "sess-1",
        kind: "summary",
        summary: "Prior run state",
        subject_links: [],
        evidence_links: [],
        expires_at: nil,
        confidence: 0.9,
        metadata: %{}
      })

    bridge = MemoryBridge.new!(downstream: Downstream)

    assert {:ok, %{write_guarantee: :best_effort}, bridge} = MemoryBridge.put_memory_record(bridge, record)
    assert {:ok, %MemoryRecord{memory_id: "memory-1"}, bridge} = MemoryBridge.get_memory_record(bridge, "memory-1", scope_id: "scope-1")
    assert {:ok, [], _bridge} = MemoryBridge.rank_memory_records(bridge, scope_id: "scope-1")
  end
end
