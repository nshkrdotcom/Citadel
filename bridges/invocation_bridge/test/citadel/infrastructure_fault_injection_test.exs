Code.require_file(Path.expand("../../../../dev/docker/toxiproxy/test_support.exs", __DIR__))

defmodule Citadel.InvocationBridgeInfrastructureFaultInjectionTest do
  use ExUnit.Case, async: false

  alias Citadel.ActionOutboxEntry
  alias Citadel.AuthorityContract.AuthorityDecision.V1, as: AuthorityDecisionV1
  alias Citadel.BackoffPolicy
  alias Citadel.BoundaryIntent
  alias Citadel.BridgeCircuitPolicy
  alias Citadel.ExecutionGovernanceCompiler
  alias Citadel.InvocationBridge
  alias Citadel.InvocationRequest.V2, as: InvocationRequestV2
  alias Citadel.LocalAction
  alias Citadel.StalenessRequirements
  alias Citadel.TestSupport.HalfOpenSocketServer
  alias Citadel.TestSupport.ToxiproxyHarness
  alias Citadel.TopologyIntent
  alias Jido.Integration.V2.SubmissionAcceptance

  @proxy_name "citadel_nginx"
  @proxy_timeout_key {__MODULE__, :proxy_timeout_ms}
  @half_open_url_key {__MODULE__, :half_open_url}

  defmodule ProxyDownstream do
    alias Citadel.TestSupport.ToxiproxyHarness

    def submit_execution_intent(envelope) do
      timeout =
        :persistent_term.get(
          {Citadel.InvocationBridgeInfrastructureFaultInjectionTest, :proxy_timeout_ms}
        )

      ToxiproxyHarness.request_url(
        :get,
        ToxiproxyHarness.proxy_url("/"),
        timeout: timeout,
        connect_timeout: timeout
      )
      |> normalize_transport_result(envelope)
    end

    defp normalize_transport_result({:ok, _response}, envelope) do
      {:accepted,
       Jido.Integration.V2.SubmissionAcceptance.new!(%{
         submission_key:
           Citadel.InvocationBridgeInfrastructureFaultInjectionTest.submission_key_for!(
             envelope.entry_id
           ),
         submission_receipt_ref: "receipt:#{envelope.entry_id}",
         status: :accepted,
         accepted_at: ~U[2026-04-11 08:00:00Z],
         ledger_version: 1
       })}
    end

    defp normalize_transport_result({:error, reason}, _envelope), do: {:error, reason}
  end

  defmodule HalfOpenDownstream do
    alias Citadel.TestSupport.ToxiproxyHarness

    def submit_execution_intent(envelope) do
      timeout = 200

      url =
        :persistent_term.get(
          {Citadel.InvocationBridgeInfrastructureFaultInjectionTest, :half_open_url}
        )

      ToxiproxyHarness.request_url(:get, url, timeout: timeout, connect_timeout: timeout)
      |> normalize_transport_result(envelope)
    end

    defp normalize_transport_result({:ok, _response}, envelope) do
      {:accepted,
       Jido.Integration.V2.SubmissionAcceptance.new!(%{
         submission_key:
           Citadel.InvocationBridgeInfrastructureFaultInjectionTest.submission_key_for!(
             envelope.entry_id
           ),
         submission_receipt_ref: "receipt:#{envelope.entry_id}",
         status: :accepted,
         accepted_at: ~U[2026-04-11 08:00:00Z],
         ledger_version: 1
       })}
    end

    defp normalize_transport_result({:error, reason}, _envelope), do: {:error, reason}
  end

  setup do
    if wave12_enabled?() do
      case ToxiproxyHarness.availability_result!(
             "Citadel.InvocationBridge Wave 12 fault injection"
           ) do
        :ok -> :ok
        {:skip, _reason} -> :ok
      end

      ToxiproxyHarness.ensure_proxy!()
      :persistent_term.put(@proxy_timeout_key, 500)
    end

    on_exit(fn ->
      if wave12_enabled?() do
        ToxiproxyHarness.ensure_proxy!()
      end

      :persistent_term.erase(@proxy_timeout_key)
      :persistent_term.erase(@half_open_url_key)
    end)

    :ok
  end

  test "real downstream latency stretches invocation submission and clears back to baseline" do
    run_wave12(fn ->
      :persistent_term.put(@proxy_timeout_key, 1_000)
      ToxiproxyHarness.add_toxic!(@proxy_name, "latency", "latency", %{"latency" => 400})

      bridge = InvocationBridge.new!(downstream: ProxyDownstream)

      {{:accepted, %SubmissionAcceptance{} = acceptance, _bridge}, delayed_ms} =
        ToxiproxyHarness.measure_ms(fn ->
          InvocationBridge.submit(bridge, invocation_request(), outbox_entry("entry-latency"))
        end)

      assert acceptance.submission_receipt_ref == "receipt:entry-latency"
      assert delayed_ms >= 350

      ToxiproxyHarness.ensure_proxy!()

      {{:accepted, %SubmissionAcceptance{} = acceptance, _bridge}, recovered_ms} =
        ToxiproxyHarness.measure_ms(fn ->
          InvocationBridge.submit(bridge, invocation_request(), outbox_entry("entry-recovered"))
        end)

      assert acceptance.submission_receipt_ref == "receipt:entry-recovered"
      assert recovered_ms < 150
    end)
  end

  test "connection drops return an explicit error instead of parking bridge work" do
    run_wave12(fn ->
      bridge = InvocationBridge.new!(downstream: ProxyDownstream)
      ToxiproxyHarness.set_enabled!(@proxy_name, false)

      {{:error, :connection_dropped, _bridge}, elapsed_ms} =
        ToxiproxyHarness.measure_ms(fn ->
          InvocationBridge.submit(bridge, invocation_request(), outbox_entry("entry-drop"))
        end)

      assert elapsed_ms < 150
    end)
  end

  test "half-open hangs time out twice and then fast-fail behind the open circuit" do
    run_wave12(fn ->
      server = start_supervised!(HalfOpenSocketServer)
      :persistent_term.put(@half_open_url_key, HalfOpenSocketServer.url(server))

      bridge =
        InvocationBridge.new!(
          downstream: HalfOpenDownstream,
          circuit_policy:
            BridgeCircuitPolicy.new!(%{
              failure_threshold: 2,
              window_ms: 5_000,
              cooldown_ms: 1_000,
              half_open_max_inflight: 1,
              scope_key_mode: "downstream_scope",
              extensions: %{}
            })
        )

      {{:error, :timeout, bridge}, first_ms} =
        ToxiproxyHarness.measure_ms(fn ->
          InvocationBridge.submit(bridge, invocation_request(), outbox_entry("entry-half-open-1"))
        end)

      assert first_ms >= 180

      {{:error, :timeout, bridge}, second_ms} =
        ToxiproxyHarness.measure_ms(fn ->
          InvocationBridge.submit(bridge, invocation_request(), outbox_entry("entry-half-open-2"))
        end)

      assert second_ms >= 180

      {{:error, :circuit_open, _bridge}, third_ms} =
        ToxiproxyHarness.measure_ms(fn ->
          InvocationBridge.submit(bridge, invocation_request(), outbox_entry("entry-half-open-3"))
        end)

      assert third_ms < 50
    end)
  end

  defp invocation_request do
    InvocationRequestV2.new!(%{
      schema_version: 2,
      invocation_request_id: "invoke-fault-1",
      request_id: "req-fault-1",
      session_id: "sess-fault-1",
      tenant_id: "tenant-fault-123",
      trace_id: "trace-fault-1",
      actor_id: "actor-fault-1",
      target_id: "target-fault-1",
      target_kind: "http",
      selected_step_id: "step-fault-1",
      allowed_operations: ["fetch"],
      authority_packet:
        AuthorityDecisionV1.new!(%{
          contract_version: "v1",
          decision_id: "dec-fault-1",
          tenant_id: "tenant-fault-123",
          request_id: "req-fault-1",
          policy_version: "policy-fault-1",
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
          topology_intent_id: "top-fault-1",
          session_mode: "attached",
          routing_hints: %{
            "execution_intent_family" => "http",
            "execution_intent" => %{
              "contract_version" => "v1",
              "method" => "POST",
              "url" => ToxiproxyHarness.proxy_url("/"),
              "headers" => %{"content-type" => "application/json"},
              "body" => %{"request" => "payload"},
              "extensions" => %{}
            },
            "downstream_scope" => "http:toxiproxy"
          },
          coordination_mode: "single_target",
          topology_epoch: 1,
          extensions: %{}
        }),
      execution_governance:
        ExecutionGovernanceCompiler.compile!(
          authority_packet(),
          boundary_intent(),
          topology_intent(),
          execution_governance_id: "execgov-fault-1",
          sandbox_level: "standard",
          sandbox_egress: "restricted",
          sandbox_approvals: "auto",
          allowed_tools: ["fetch_http"],
          file_scope_ref: "workspace://project/main",
          logical_workspace_ref: "workspace://project/main",
          workspace_mutability: "read_write",
          execution_family: "http",
          placement_intent: "host_local",
          target_kind: "http",
          allowed_operations: ["fetch"],
          effect_classes: ["network_http"]
        ),
      extensions: %{
        "citadel" => %{
          "execution_intent_family" => "http",
          "execution_intent" => %{
            "contract_version" => "v1",
            "method" => "POST",
            "url" => ToxiproxyHarness.proxy_url("/"),
            "headers" => %{"content-type" => "application/json"},
            "body" => %{"request" => "payload"},
            "extensions" => %{}
          }
        }
      }
    })
  end

  defp authority_packet do
    AuthorityDecisionV1.new!(%{
      contract_version: "v1",
      decision_id: "dec-fault-1",
      tenant_id: "tenant-fault-123",
      request_id: "req-fault-1",
      policy_version: "policy-fault-1",
      boundary_class: "workspace_session",
      trust_profile: "trusted_operator",
      approval_profile: "approval_optional",
      egress_profile: "restricted",
      workspace_profile: "project_workspace",
      resource_profile: "standard",
      decision_hash: "c941cfcdae563437fb6f200c3b7abecdc70c5a23273d81301c86e2364ead04e9",
      extensions: %{}
    })
  end

  defp boundary_intent do
    BoundaryIntent.new!(%{
      boundary_class: "workspace_session",
      trust_profile: "trusted_operator",
      workspace_profile: "project_workspace",
      resource_profile: "standard",
      requested_attach_mode: "fresh_or_reuse",
      requested_ttl_ms: 30_000,
      extensions: %{}
    })
  end

  defp topology_intent do
    TopologyIntent.new!(%{
      topology_intent_id: "top-fault-1",
      session_mode: "attached",
      routing_hints: %{
        "execution_intent_family" => "http",
        "execution_intent" => %{
          "contract_version" => "v1",
          "method" => "POST",
          "url" => ToxiproxyHarness.proxy_url("/"),
          "headers" => %{"content-type" => "application/json"},
          "body" => %{"request" => "payload"},
          "extensions" => %{}
        },
        "downstream_scope" => "http:toxiproxy"
      },
      coordination_mode: "single_target",
      topology_epoch: 1,
      extensions: %{}
    })
  end

  defp outbox_entry(entry_id) do
    ActionOutboxEntry.new!(%{
      schema_version: 1,
      entry_id: entry_id,
      causal_group_id: "group-fault-1",
      action:
        LocalAction.new!(%{
          action_kind: "submit_invocation",
          payload: %{"request_id" => "req-fault-1"},
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

  def submission_key_for!(seed) when is_binary(seed) do
    "sha256:" <> (:crypto.hash(:sha256, seed) |> Base.encode16(case: :lower))
  end

  defp run_wave12(fun) when is_function(fun, 0) do
    if wave12_enabled?(), do: fun.(), else: :ok
  end

  defp wave12_enabled? do
    System.get_env("CITADEL_REQUIRE_TOXIPROXY") == "1"
  end
end
