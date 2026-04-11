defmodule Citadel.InvocationBridgeTest do
  use ExUnit.Case, async: true

  alias Citadel.ActionOutboxEntry
  alias Citadel.AuthorityContract.AuthorityDecision.V1, as: AuthorityDecisionV1
  alias Citadel.BackoffPolicy
  alias Citadel.BoundaryIntent
  alias Citadel.BridgeCircuitPolicy
  alias Citadel.InvocationBridge
  alias Citadel.InvocationRequest
  alias Citadel.LocalAction
  alias Citadel.StalenessRequirements
  alias Citadel.TopologyIntent

  defmodule Downstream do
    def submit_execution_intent(envelope) do
      send(Process.get(:invocation_bridge_test_pid), {:submitted, envelope})
      {:ok, "receipt:#{envelope.entry_id}"}
    end
  end

  defmodule FailingDownstream do
    def submit_execution_intent(_envelope), do: {:error, :timeout}
  end

  setup do
    Process.put(:invocation_bridge_test_pid, self())
    :ok
  end

  test "projects the explicit lower execution handoff and deduplicates by entry_id" do
    bridge = InvocationBridge.new!(downstream: Downstream)
    request = invocation_request()
    entry = outbox_entry("entry-1")

    assert {:ok, "receipt:entry-1", bridge_after_submit} =
             InvocationBridge.submit(bridge, request, entry)

    assert_receive {:submitted, envelope}
    assert envelope.entry_id == "entry-1"
    assert envelope.causal_group_id == entry.causal_group_id
    assert envelope.invocation_schema_version == 1
    assert envelope.execution_intent_family == "http"
    assert envelope.authority_packet == request.authority_packet

    assert {:ok, "receipt:entry-1", ^bridge_after_submit} =
             InvocationBridge.submit(bridge_after_submit, request, entry)

    refute_receive {:submitted, _envelope}
  end

  test "rejects unsupported invocation schema versions at bridge entry" do
    bridge = InvocationBridge.new!(downstream: Downstream)

    request = %{invocation_request() | schema_version: 2}

    assert {:error, :unsupported_schema_version, ^bridge} =
             InvocationBridge.submit(bridge, request, outbox_entry("entry-2"))

    refute_receive {:submitted, _envelope}
  end

  test "shares receipt deduplication across fresh bridge instances when state_name is reused" do
    state_name = unique_name(:invocation_bridge_state)
    request = invocation_request()
    entry = outbox_entry("entry-shared")

    bridge =
      InvocationBridge.new!(
        downstream: Downstream,
        state_name: state_name
      )

    assert {:ok, "receipt:entry-shared", _bridge} =
             InvocationBridge.submit(bridge, request, entry)

    assert_receive {:submitted, _envelope}

    fresh_bridge =
      InvocationBridge.new!(
        downstream: Downstream,
        state_name: state_name
      )

    assert {:ok, "receipt:entry-shared", _fresh_bridge} =
             InvocationBridge.submit(fresh_bridge, request, entry)

    refute_receive {:submitted, _envelope}
  end

  test "allows an explicit invocation schema transition window instead of hardcoding the current schema only" do
    bridge =
      InvocationBridge.new!(
        downstream: Downstream,
        supported_invocation_request_schema_versions: [1, 2]
      )

    request = %{invocation_request() | schema_version: 2}

    assert {:ok, "receipt:entry-transition", _bridge} =
             InvocationBridge.submit(bridge, request, outbox_entry("entry-transition"))

    assert_receive {:submitted, envelope}
    assert envelope.invocation_schema_version == 2
  end

  test "fast-fails once the downstream circuit is open" do
    {:ok, clock} = Agent.start_link(fn -> 0 end)

    bridge =
      InvocationBridge.new!(
        downstream: FailingDownstream,
        circuit_policy:
          BridgeCircuitPolicy.new!(%{
            failure_threshold: 2,
            window_ms: 100,
            cooldown_ms: 50,
            half_open_max_inflight: 1,
            scope_key_mode: "downstream_scope",
            extensions: %{}
          }),
        now_ms_fun: fn -> Agent.get(clock, & &1) end
      )

    assert {:error, :timeout, bridge} =
             InvocationBridge.submit(bridge, invocation_request(), outbox_entry("entry-3"))

    assert {:error, :timeout, bridge} =
             InvocationBridge.submit(bridge, invocation_request(), outbox_entry("entry-4"))

    assert {:error, :circuit_open, _bridge} =
             InvocationBridge.submit(bridge, invocation_request(), outbox_entry("entry-5"))
  end

  test "recreates bridge state by name after the underlying state process dies" do
    bridge =
      InvocationBridge.new!(
        downstream: Downstream,
        state_name: unique_name(:invocation_bridge_state_restart)
      )

    state_server =
      bridge
      |> Map.fetch!(:state_ref)
      |> Citadel.BridgeState.server()

    Process.exit(state_server, :kill)
    wait_until(fn -> not Process.alive?(state_server) end)

    assert {:ok, "receipt:entry-restarted", _bridge} =
             InvocationBridge.submit(
               bridge,
               invocation_request(),
               outbox_entry("entry-restarted")
             )

    assert_receive {:submitted, envelope}
    assert envelope.entry_id == "entry-restarted"
  end

  defp invocation_request do
    InvocationRequest.new!(%{
      schema_version: 1,
      invocation_request_id: "invoke-1",
      request_id: "req-1",
      session_id: "sess-1",
      tenant_id: "tenant-123",
      trace_id: "trace-1",
      actor_id: "actor-1",
      target_id: "target-1",
      target_kind: "http",
      selected_step_id: "step-1",
      allowed_operations: ["fetch"],
      authority_packet:
        AuthorityDecisionV1.new!(%{
          contract_version: "v1",
          decision_id: "dec-1",
          tenant_id: "tenant-123",
          request_id: "req-1",
          policy_version: "policy-1",
          boundary_class: "workspace_session",
          trust_profile: "trusted_operator",
          approval_profile: "approval_optional",
          egress_profile: "restricted",
          workspace_profile: "project_workspace",
          resource_profile: "standard",
          decision_hash: "c941cfcdae563437fb6f200c3b7abecdc70c5a23273d81301c86e2364ead04e9",
          extensions: %{}
        }),
      boundary_intent:
        BoundaryIntent.new!(%{
          boundary_class: "workspace_session",
          trust_profile: "trusted_operator",
          workspace_profile: "project_workspace",
          resource_profile: "standard",
          requested_attach_mode: "fresh_or_reuse",
          requested_ttl_ms: 30_000,
          extensions: %{}
        }),
      topology_intent:
        TopologyIntent.new!(%{
          topology_intent_id: "top-1",
          session_mode: "attached",
          routing_hints: %{
            "execution_intent_family" => "http",
            "execution_intent" => %{
              "contract_version" => "v1",
              "method" => "POST",
              "url" => "https://example.test/invoke",
              "headers" => %{"content-type" => "application/json"},
              "body" => %{"request" => "payload"},
              "extensions" => %{}
            },
            "downstream_scope" => "http:example.test"
          },
          coordination_mode: "single_target",
          topology_epoch: 1,
          extensions: %{}
        }),
      extensions: %{
        "citadel" => %{
          "execution_intent_family" => "http",
          "execution_intent" => %{
            "contract_version" => "v1",
            "method" => "POST",
            "url" => "https://example.test/invoke",
            "headers" => %{"content-type" => "application/json"},
            "body" => %{"request" => "payload"},
            "extensions" => %{}
          }
        }
      }
    })
  end

  defp outbox_entry(entry_id) do
    ActionOutboxEntry.new!(%{
      schema_version: 1,
      entry_id: entry_id,
      causal_group_id: "group-1",
      action:
        LocalAction.new!(%{
          action_kind: "submit_invocation",
          payload: %{"request_id" => "req-1"},
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
          max_delay_ms: 10,
          linear_step_ms: nil,
          multiplier: nil,
          jitter_mode: :none,
          jitter_window_ms: 0,
          extensions: %{}
        }),
      next_attempt_at: nil,
      last_error_code: nil,
      dead_letter_reason: nil,
      ordering_mode: :strict,
      staleness_mode: :requires_check,
      staleness_requirements:
        StalenessRequirements.new!(%{
          snapshot_seq: 1,
          policy_epoch: 1,
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
