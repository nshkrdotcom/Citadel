defmodule Citadel.Runtime.RuntimeCoordinationTest do
  use ExUnit.Case, async: false

  alias Citadel.ActionOutboxEntry
  alias Citadel.BackoffPolicy
  alias Citadel.BoundaryLeaseView
  alias Citadel.LocalAction
  alias Citadel.PersistedSessionBlob
  alias Citadel.PersistedSessionEnvelope
  alias Citadel.Runtime.BoundaryLeaseTracker
  alias Citadel.Runtime.KernelSnapshot
  alias Citadel.Runtime.PolicyCache
  alias Citadel.Runtime.ServiceCatalog
  alias Citadel.Runtime.SessionDirectory
  alias Citadel.Runtime.SessionServer
  alias Citadel.Runtime.SignalIngress
  alias Citadel.ScopeRef
  alias Citadel.ServiceDescriptor
  alias Citadel.SessionContinuityCommit
  alias Citadel.SessionOutbox
  alias Citadel.SignalIngressRebuildPolicy
  alias Citadel.StalenessRequirements

  defmodule TestSignalSource do
    @behaviour Citadel.Ports.SignalSource

    @impl true
    def normalize_signal(observation), do: {:ok, observation}
  end

  test "kernel snapshot publishes whole immutable terms and policy owner coalesces bursty updates" do
    kernel_snapshot_name = unique_name(:kernel_snapshot)
    policy_cache_name = unique_name(:policy_cache)

    start_supervised!({KernelSnapshot, name: kernel_snapshot_name, policy_version: "v0"})
    start_supervised!({PolicyCache, name: policy_cache_name, kernel_snapshot: kernel_snapshot_name, flush_interval_ms: 15})

    assert {:ok, 1} = PolicyCache.update_policy(policy_cache_name, "v1", %{"version" => 1})
    assert {:ok, 2} = PolicyCache.update_policy(policy_cache_name, "v2", %{"version" => 2})

    Process.sleep(30)

    snapshot = KernelSnapshot.current_snapshot(kernel_snapshot_name)
    assert snapshot.policy_version == "v2"
    assert snapshot.policy_epoch == 2
    assert snapshot.snapshot_seq == 1

    assert {:ok, 2} = PolicyCache.update_policy(policy_cache_name, "v2", %{"version" => 2})
    Process.sleep(20)
    assert KernelSnapshot.current_snapshot(kernel_snapshot_name).snapshot_seq == 1
  end

  test "session directory uses ambiguous acknowledgement recovery reads and fences stale writers" do
    kernel_snapshot_name = unique_name(:kernel_snapshot)
    session_directory_name = unique_name(:session_directory)

    start_supervised!({KernelSnapshot, name: kernel_snapshot_name})
    start_supervised!({SessionDirectory, name: session_directory_name, kernel_snapshot: kernel_snapshot_name})

    assert {:ok, %{blob: claimed_blob}} = SessionDirectory.claim_session(session_directory_name, "sess-1")

    entry = outbox_entry("entry-1", "submit_invocation", %{"target" => "compile"}, %{policy_epoch: 0})

    persisted_blob =
      PersistedSessionBlob.new!(%{
        schema_version: 1,
        session_id: "sess-1",
        envelope:
          PersistedSessionEnvelope.new!(%{
            schema_version: 1,
            session_id: "sess-1",
            continuity_revision: claimed_blob.envelope.continuity_revision + 1,
            owner_incarnation: claimed_blob.envelope.owner_incarnation,
            project_binding: claimed_blob.envelope.project_binding,
            scope_ref: claimed_blob.envelope.scope_ref,
            signal_cursor: nil,
            recent_signal_hashes: [],
            lifecycle_status: :active,
            last_active_at: nil,
            active_plan: nil,
            active_authority_decision: nil,
            last_rejection: nil,
            boundary_ref: nil,
            outbox_entry_ids: [entry.entry_id],
            external_refs: %{},
            extensions: %{}
          }),
        outbox_entries: %{entry.entry_id => entry},
        extensions: %{}
      })

    commit =
      SessionContinuityCommit.new!(%{
        session_id: "sess-1",
        expected_continuity_revision: claimed_blob.envelope.continuity_revision,
        expected_owner_incarnation: claimed_blob.envelope.owner_incarnation,
        persisted_blob: persisted_blob,
        extensions: %{}
      })

    :ok =
      SessionDirectory.configure_fault_injection(session_directory_name, fn _commit ->
        {:error, :acknowledgement_ambiguous, :committed}
      end)

    assert {:error, :acknowledgement_ambiguous} =
             SessionDirectory.commit_continuity(session_directory_name, commit)

    assert {:ok, recovered_blob} = SessionDirectory.fetch_persisted_blob(session_directory_name, "sess-1")
    assert recovered_blob.envelope.continuity_revision == persisted_blob.envelope.continuity_revision
    assert Map.has_key?(recovered_blob.outbox_entries, entry.entry_id)

    :ok = SessionDirectory.configure_fault_injection(session_directory_name, fn _commit -> :ok end)

    assert {:error, :stale_continuity_revision} =
             SessionDirectory.commit_continuity(session_directory_name, commit)
  end

  test "boundary bootstrap coalesces equivalent requests and fast-fails when the bridge circuit is open" do
    kernel_snapshot_name = unique_name(:kernel_snapshot)
    boundary_tracker_name = unique_name(:boundary_tracker)
    counter = start_supervised!({Agent, fn -> 0 end})

    start_supervised!({KernelSnapshot, name: kernel_snapshot_name})

    start_supervised!(
      {BoundaryLeaseTracker,
       name: boundary_tracker_name,
       kernel_snapshot: kernel_snapshot_name,
       classification_key_fun: fn
         "blocked-boundary" -> "blocked-key"
         _other -> "shared-key"
       end,
       bootstrap_fun: fn boundary_ref ->
         Agent.update(counter, &(&1 + 1))
         Process.sleep(20)

         {:ok,
          BoundaryLeaseView.new!(%{
            boundary_ref: boundary_ref,
            last_heartbeat_at: nil,
            expires_at: nil,
            staleness_status: :missing,
            lease_epoch: 1,
            extensions: %{}
          })}
       end})

    task_a = Task.async(fn -> BoundaryLeaseTracker.classify_for_resume(boundary_tracker_name, "boundary-a") end)
    task_b = Task.async(fn -> BoundaryLeaseTracker.classify_for_resume(boundary_tracker_name, "boundary-b") end)

    assert {:ok, %BoundaryLeaseView{staleness_status: :missing}} = Task.await(task_a, 1_000)
    assert {:ok, %BoundaryLeaseView{staleness_status: :missing}} = Task.await(task_b, 1_000)
    assert Agent.get(counter, & &1) == 1

    assert :ok = BoundaryLeaseTracker.set_circuit_open(boundary_tracker_name, "blocked-key", true)
    assert {:error, :circuit_open} =
             BoundaryLeaseTracker.classify_for_resume(boundary_tracker_name, "blocked-boundary")
  end

  test "signal ingress rebuild restores high-priority sessions before colder backlog" do
    kernel_snapshot_name = unique_name(:kernel_snapshot)
    session_directory_name = unique_name(:session_directory)
    signal_ingress_name = unique_name(:signal_ingress)

    start_supervised!({KernelSnapshot, name: kernel_snapshot_name})
    start_supervised!({SessionDirectory, name: session_directory_name, kernel_snapshot: kernel_snapshot_name})

    assert :ok =
             SessionDirectory.register_active_session(session_directory_name, "sess-explicit",
               committed_signal_cursor: "cursor-1",
               priority_class: "explicit_resume"
             )

    assert :ok =
             SessionDirectory.register_active_session(session_directory_name, "sess-replay",
               committed_signal_cursor: "cursor-2",
               priority_class: "pending_replay_safe"
             )

    assert :ok =
             SessionDirectory.register_active_session(session_directory_name, "sess-cold",
               committed_signal_cursor: "cursor-3",
               priority_class: "background"
             )

    start_supervised!(
      {SignalIngress,
       name: signal_ingress_name,
       session_directory: session_directory_name,
       signal_source: TestSignalSource,
       rebuild_policy:
         SignalIngressRebuildPolicy.new!(%{
           max_sessions_per_batch: 2,
           batch_interval_ms: 100,
           high_priority_ready_slo_ms: 5_000,
           priority_order: ["explicit_resume", "live_request", "pending_replay_safe", "background"],
           extensions: %{}
         })})

    assert :ok = SignalIngress.rebuild_from_directory(signal_ingress_name)

    Process.sleep(20)

    first_snapshot = SignalIngress.snapshot(signal_ingress_name)
    assert Map.has_key?(first_snapshot.subscriptions, "sess-explicit")
    assert Map.has_key?(first_snapshot.subscriptions, "sess-replay")
    refute Map.has_key?(first_snapshot.subscriptions, "sess-cold")

    Process.sleep(120)

    second_snapshot = SignalIngress.snapshot(signal_ingress_name)
    assert Map.has_key?(second_snapshot.subscriptions, "sess-cold")
  end

  test "session server supersedes stale replay-safe work, commits before dispatch, and routes service lifecycle through service catalog" do
    test_pid = self()
    kernel_snapshot_name = unique_name(:kernel_snapshot)
    session_directory_name = unique_name(:session_directory)
    service_catalog_name = unique_name(:service_catalog)
    boundary_tracker_name = unique_name(:boundary_tracker)
    signal_ingress_name = unique_name(:signal_ingress)
    invocation_supervisor_name = unique_name(:invocation_supervisor)
    projection_supervisor_name = unique_name(:projection_supervisor)
    local_supervisor_name = unique_name(:local_supervisor)
    session_server_name = unique_name(:session_server)

    start_supervised!({KernelSnapshot, name: kernel_snapshot_name, policy_version: "v1", policy_epoch: 1})
    start_supervised!({SessionDirectory, name: session_directory_name, kernel_snapshot: kernel_snapshot_name})
    start_supervised!({ServiceCatalog, name: service_catalog_name, kernel_snapshot: kernel_snapshot_name})
    start_supervised!({BoundaryLeaseTracker, name: boundary_tracker_name, kernel_snapshot: kernel_snapshot_name})
    start_supervised!({Task.Supervisor, name: invocation_supervisor_name, max_children: 4})
    start_supervised!({Task.Supervisor, name: projection_supervisor_name, max_children: 4})
    start_supervised!({Task.Supervisor, name: local_supervisor_name, max_children: 4})

    start_supervised!(
      {SignalIngress,
       name: signal_ingress_name,
       session_directory: session_directory_name,
       signal_source: TestSignalSource})

    stale_entry = outbox_entry("stale-entry", "submit_invocation", %{"target" => "compile"}, %{policy_epoch: 0})

    :ok =
      SessionDirectory.seed_raw_blob(
        session_directory_name,
        "sess-runtime",
        PersistedSessionBlob.new!(%{
          schema_version: 1,
          session_id: "sess-runtime",
          envelope:
            PersistedSessionEnvelope.new!(%{
              schema_version: 1,
              session_id: "sess-runtime",
              continuity_revision: 1,
              owner_incarnation: 1,
              project_binding: nil,
              scope_ref:
                ScopeRef.new!(%{
                  scope_id: "scope-1",
                  scope_kind: "workspace",
                  workspace_root: "/workspace",
                  environment: "test",
                  catalog_epoch: 1,
                  extensions: %{}
                }),
              signal_cursor: nil,
              recent_signal_hashes: [],
              lifecycle_status: :active,
              last_active_at: nil,
              active_plan: nil,
              active_authority_decision: nil,
              last_rejection: nil,
              boundary_ref: nil,
              outbox_entry_ids: [stale_entry.entry_id],
              external_refs: %{"trace_id" => "trace-runtime"},
              extensions: %{}
            }),
          outbox_entries: %{stale_entry.entry_id => stale_entry},
          extensions: %{}
        })
      )

    blocking_handler = fn _action, entry, _state ->
      send(test_pid, {:dispatch_started, entry.entry_id, self()})

      receive do
        {:continue_dispatch, ^entry.entry_id} -> {:ok, "local/#{entry.entry_id}"}
      after
        1_000 -> {:error, :timeout}
      end
    end

    start_supervised!(
      {SessionServer,
       name: session_server_name,
       session_id: "sess-runtime",
       session_directory: session_directory_name,
       kernel_snapshot: kernel_snapshot_name,
       boundary_lease_tracker: boundary_tracker_name,
       service_catalog: service_catalog_name,
       signal_ingress: signal_ingress_name,
       invocation_supervisor: invocation_supervisor_name,
       projection_supervisor: projection_supervisor_name,
       local_supervisor: local_supervisor_name,
       local_handler: blocking_handler})

    wait_until(fn ->
      session_state = SessionServer.snapshot(session_server_name)
      stale = Map.fetch!(session_state.outbox.entries_by_id, stale_entry.entry_id)

      stale.replay_status == :superseded and
        Enum.any?(session_state.outbox.entries_by_id, fn {_entry_id, entry} -> entry.action.action_kind == "enqueue_redecision" end)
    end)

    probe_entry =
      outbox_entry(
        "probe-entry",
        "local_probe",
        %{"probe" => true},
        %{policy_epoch: 1}
      )

    assert {:ok, _session_state} =
             SessionServer.commit_transition(
               session_server_name,
               fn session_state ->
                 %{outbox: SessionOutbox.put_entry!(session_state.outbox, probe_entry)}
               end
             )

    assert_receive {:dispatch_started, "probe-entry", handler_pid}, 1_000

    assert {:ok, persisted_probe_blob} =
             SessionDirectory.fetch_persisted_blob(session_directory_name, "sess-runtime")

    assert Map.has_key?(persisted_probe_blob.outbox_entries, "probe-entry")

    send(handler_pid, {:continue_dispatch, "probe-entry"})

    wait_until(fn ->
      session_state = SessionServer.snapshot(session_server_name)
      Map.fetch!(session_state.outbox.entries_by_id, "probe-entry").replay_status == :completed
    end)

    register_entry =
      outbox_entry(
        "service-register",
        "service_catalog_register",
        %{
          "service_descriptor" =>
            ServiceDescriptor.new!(%{
              service_id: "svc-1",
              service_kind: "agent",
              capabilities: ["code"],
              visibility: "global",
              admission_epoch: 0,
              extensions: %{}
            })
        },
        %{policy_epoch: 1}
      )

    assert {:ok, _session_state} =
             SessionServer.commit_transition(
               session_server_name,
               fn session_state ->
                 %{outbox: SessionOutbox.put_entry!(session_state.outbox, register_entry)}
               end
             )

    assert {:ok, persisted_blob} = SessionDirectory.fetch_persisted_blob(session_directory_name, "sess-runtime")
    assert Map.has_key?(persisted_blob.outbox_entries, "service-register")

    wait_until(fn ->
      ServiceCatalog.visible_services(service_catalog_name)
      |> Enum.any?(&(&1.service_id == "svc-1"))
    end)
  end

  defp outbox_entry(entry_id, action_kind, payload, opts) do
    policy_epoch = Map.get(opts, :policy_epoch)

    ActionOutboxEntry.new!(%{
      schema_version: 1,
      entry_id: entry_id,
      causal_group_id: "group-1",
      action:
        LocalAction.new!(%{
          action_kind: action_kind,
          payload: payload,
          extensions: %{}
        }),
      inserted_at: ~U[2026-04-10 10:00:00Z],
      replay_status: :pending,
      durable_receipt_ref: nil,
      attempt_count: 0,
      max_attempts: 3,
      backoff_policy:
        BackoffPolicy.new!(%{
          strategy: :fixed,
          base_delay_ms: 10,
          max_delay_ms: 50,
          linear_step_ms: nil,
          multiplier: nil,
          jitter_mode: :entry_stable,
          jitter_window_ms: 5,
          extensions: %{}
        }),
      next_attempt_at: nil,
      last_error_code: nil,
      dead_letter_reason: nil,
      ordering_mode: :strict,
      staleness_mode: :requires_check,
      staleness_requirements:
        StalenessRequirements.new!(%{
          snapshot_seq: 0,
          policy_epoch: policy_epoch,
          topology_epoch: nil,
          scope_catalog_epoch: nil,
          service_admission_epoch: nil,
          project_binding_epoch: nil,
          boundary_epoch: nil,
          required_binding_id: nil,
          required_boundary_ref: nil,
          extensions: %{}
        }),
      extensions: %{}
    })
  end

  defp unique_name(prefix) do
    :"#{prefix}_#{System.unique_integer([:positive])}"
  end

  defp wait_until(fun, attempts \\ 40)

  defp wait_until(fun, attempts) when attempts > 0 do
    if fun.() do
      :ok
    else
      Process.sleep(25)
      wait_until(fun, attempts - 1)
    end
  end

  defp wait_until(_fun, 0) do
    flunk("condition did not become true in time")
  end
end
