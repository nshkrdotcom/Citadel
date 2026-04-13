defmodule Citadel.DomainSurface.CitadelHostIngressSurfaceTest do
  use ExUnit.Case, async: false

  alias Citadel.HostIngress.InvocationPayload
  alias Citadel.Runtime.BoundaryLeaseTracker
  alias Citadel.Runtime.KernelSnapshot
  alias Citadel.Runtime.ServiceCatalog
  alias Citadel.Runtime.SessionDirectory
  alias Citadel.Runtime.SessionServer
  alias Citadel.Runtime.SignalIngress
  alias Citadel.DomainSurface.Adapters.CitadelAdapter
  alias Citadel.DomainSurface.Adapters.CitadelAdapter.Accepted
  alias Citadel.DomainSurface.Examples.ProvingGround.Commands
  alias Jido.Integration.V2.SubmissionAcceptance

  defmodule TestSignalSource do
    @behaviour Citadel.Ports.SignalSource

    @impl true
    def normalize_signal(observation), do: {:ok, observation}
  end

  setup do
    kernel_snapshot_name = unique_name(:kernel_snapshot)
    session_directory_name = unique_name(:session_directory)
    service_catalog_name = unique_name(:service_catalog)
    boundary_tracker_name = unique_name(:boundary_tracker)
    signal_ingress_name = unique_name(:signal_ingress)
    invocation_supervisor_name = unique_name(:invocation_supervisor)
    projection_supervisor_name = unique_name(:projection_supervisor)
    local_supervisor_name = unique_name(:local_supervisor)

    start_supervised!(
      {KernelSnapshot, name: kernel_snapshot_name, policy_version: "policy-v1", policy_epoch: 7}
    )

    start_supervised!(
      {SessionDirectory, name: session_directory_name, kernel_snapshot: kernel_snapshot_name}
    )

    start_supervised!(
      {ServiceCatalog, name: service_catalog_name, kernel_snapshot: kernel_snapshot_name}
    )

    start_supervised!(
      {BoundaryLeaseTracker, name: boundary_tracker_name, kernel_snapshot: kernel_snapshot_name}
    )

    start_supervised!({Task.Supervisor, name: invocation_supervisor_name, max_children: 4})
    start_supervised!({Task.Supervisor, name: projection_supervisor_name, max_children: 4})
    start_supervised!({Task.Supervisor, name: local_supervisor_name, max_children: 4})

    start_supervised!(
      {SignalIngress,
       name: signal_ingress_name,
       session_directory: session_directory_name,
       signal_source: TestSignalSource}
    )

    {:ok,
     kernel_snapshot: kernel_snapshot_name,
     session_directory: session_directory_name,
     service_catalog: service_catalog_name,
     boundary_tracker: boundary_tracker_name,
     signal_ingress: signal_ingress_name,
     invocation_supervisor: invocation_supervisor_name,
     projection_supervisor: projection_supervisor_name,
     local_supervisor: local_supervisor_name}
  end

  test "dispatches a typed domain command through the real Citadel host-ingress surface", env do
    session_id = "sess-domain-host-ingress"
    test_pid = self()

    {:ok, session_server} =
      SessionServer.start_link(
        name: unique_name(:session_server),
        session_id: session_id,
        session_directory: env.session_directory,
        kernel_snapshot: env.kernel_snapshot,
        boundary_lease_tracker: env.boundary_tracker,
        service_catalog: env.service_catalog,
        signal_ingress: env.signal_ingress,
        invocation_supervisor: env.invocation_supervisor,
        projection_supervisor: env.projection_supervisor,
        local_supervisor: env.local_supervisor,
        invocation_handler: fn payload, attempt_entry ->
          request = InvocationPayload.decode!(payload)
          send(test_pid, {:invocation_request, request, attempt_entry})

          {:accepted,
           SubmissionAcceptance.new!(%{
             submission_key: "sha256:#{String.duplicate("b", 64)}",
             submission_receipt_ref: "submission/#{request.request_id}",
             status: :accepted,
             accepted_at: ~U[2026-04-12 08:00:00Z],
             ledger_version: 1
           })}
        end
      )

    runtime_opts =
      CitadelAdapter.runtime_opts(
        request_submission_opts: [
          session_directory: env.session_directory,
          policy_packs: [policy_pack()],
          lookup_session: fn ^session_id -> {:ok, session_server} end
        ]
      )

    assert {:ok, %Accepted{} = accepted} =
             Citadel.DomainSurface.submit(
               Commands.CompileWorkspace,
               %{workspace_id: "workspace/main"},
               idempotency_key: "cmd-live-domain",
               context: %{
                 trace_id: "trace/domain-live",
                 session_id: session_id,
                 tenant_id: "tenant-1",
                 actor_id: "actor-1",
                 environment: "dev"
               },
               kernel_runtime: {CitadelAdapter, runtime_opts}
             )

    assert accepted.request_id == "cmd-live-domain"
    assert accepted.trace_id == "trace/domain-live"
    assert accepted.session_id == session_id
    assert accepted.lifecycle_event == :live_owner

    assert_receive {:invocation_request, request, attempt_entry}
    assert request.request_id == "cmd-live-domain"

    assert request.extensions["citadel"]["execution_intent"]["args"] == [
             "compile",
             "workspace/main"
           ]

    assert attempt_entry.entry_id == "submit/cmd-live-domain"

    wait_until(fn ->
      case SessionDirectory.resolve_outbox_entry(env.session_directory, attempt_entry.entry_id) do
        {:ok, %{entry: entry}} ->
          entry.replay_status == :submission_accepted and
            entry.submission_receipt_ref == "submission/cmd-live-domain"

        _other ->
          false
      end
    end)
  end

  defp policy_pack do
    %{
      pack_id: "default",
      policy_version: "policy-v1",
      policy_epoch: 7,
      priority: 0,
      selector: %{
        tenant_ids: [],
        scope_kinds: [],
        environments: [],
        default?: true,
        extensions: %{}
      },
      profiles: %{
        trust_profile: "baseline",
        approval_profile: "standard",
        egress_profile: "restricted",
        workspace_profile: "workspace",
        resource_profile: "standard",
        boundary_class: "workspace_session",
        extensions: %{}
      },
      rejection_policy: %{
        runtime_change_reason_codes: ["scope_changed"],
        governance_change_reason_codes: ["governance_changed"],
        denial_audit_reason_codes: ["policy_denied"],
        derived_state_reason_codes: [],
        extensions: %{}
      },
      extensions: %{}
    }
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

  defp wait_until(_fun, 0), do: flunk("condition did not become true in time")

  defp unique_name(prefix) do
    {:global, {__MODULE__, prefix, System.unique_integer([:positive])}}
  end
end
