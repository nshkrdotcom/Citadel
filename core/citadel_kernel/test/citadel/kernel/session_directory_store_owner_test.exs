defmodule Citadel.Kernel.SessionDirectoryStoreOwnerTest do
  use ExUnit.Case, async: false

  alias Citadel.Kernel.KernelSnapshot
  alias Citadel.Kernel.SessionDirectory
  alias Citadel.Kernel.SessionDirectory.StoreOwner
  alias Citadel.PersistedSessionBlob

  test "committed store survives session directory restart through supervised store owner" do
    kernel_snapshot_name = unique_name(:kernel_snapshot)
    store_owner_name = unique_name(:store_owner)
    session_directory_name = unique_name(:session_directory)
    store_key = {__MODULE__, :restart, System.unique_integer([:positive])}
    child_id = {__MODULE__, :session_directory_restart}

    start_supervised!({KernelSnapshot, name: kernel_snapshot_name})
    start_supervised!({StoreOwner, name: store_owner_name})

    child_spec =
      {SessionDirectory,
       name: session_directory_name,
       kernel_snapshot: kernel_snapshot_name,
       store_owner: store_owner_name,
       store_key: store_key}

    start_supervised!(child_spec, id: child_id)

    assert {:ok, %{blob: claimed_blob}} =
             SessionDirectory.claim_session(session_directory_name, "sess-restart")

    assert {:ok, %PersistedSessionBlob{session_id: "sess-restart"}} =
             SessionDirectory.fetch_persisted_blob(session_directory_name, "sess-restart")

    :ok = stop_supervised!(child_id)
    start_supervised!(child_spec, id: child_id)

    assert {:ok, %PersistedSessionBlob{} = reloaded_blob} =
             SessionDirectory.fetch_persisted_blob(session_directory_name, "sess-restart")

    assert reloaded_blob.session_id == "sess-restart"

    assert reloaded_blob.envelope.continuity_revision ==
             claimed_blob.envelope.continuity_revision

    assert reloaded_blob.envelope.owner_incarnation == claimed_blob.envelope.owner_incarnation
  end

  test "concurrent active-session reads use the committed owner-backed store" do
    kernel_snapshot_name = unique_name(:kernel_snapshot)
    store_owner_name = unique_name(:store_owner)
    session_directory_name = unique_name(:session_directory)
    task_supervisor_name = unique_name(:task_supervisor)

    start_supervised!({KernelSnapshot, name: kernel_snapshot_name})
    start_supervised!({StoreOwner, name: store_owner_name})
    start_supervised!({Task.Supervisor, name: task_supervisor_name})

    start_supervised!(
      {SessionDirectory,
       name: session_directory_name,
       kernel_snapshot: kernel_snapshot_name,
       store_owner: store_owner_name}
    )

    expected_session_ids =
      1..5
      |> Enum.map(fn index ->
        session_id = "sess-active-#{index}"

        assert :ok =
                 SessionDirectory.register_active_session(session_directory_name, session_id,
                   tenant_id: "tenant-1",
                   authority_scope: "authority-1",
                   committed_signal_cursor: "cursor-#{index}"
                 )

        session_id
      end)
      |> Enum.sort()

    results =
      Task.Supervisor.async_stream_nolink(
        task_supervisor_name,
        1..20,
        fn _index ->
          session_directory_name
          |> SessionDirectory.list_active_session_cursors()
          |> Enum.map(& &1.session_id)
          |> Enum.sort()
        end,
        max_concurrency: 4,
        ordered: false
      )
      |> Enum.map(fn {:ok, session_ids} -> session_ids end)

    assert Enum.all?(results, &(&1 == expected_session_ids))
  end

  defp unique_name(prefix),
    do: {:global, {__MODULE__, prefix, System.unique_integer([:positive, :monotonic])}}
end
