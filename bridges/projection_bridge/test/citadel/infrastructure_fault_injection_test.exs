Code.require_file(Path.expand("../../../../dev/docker/toxiproxy/test_support.exs", __DIR__))

defmodule Citadel.ProjectionBridgeInfrastructureFaultInjectionTest do
  use ExUnit.Case, async: false

  alias Citadel.ActionOutboxEntry
  alias Citadel.BackoffPolicy
  alias Citadel.BridgeCircuitPolicy
  alias Citadel.LocalAction
  alias Citadel.ProjectionBridge
  alias Citadel.RuntimeObservation
  alias Citadel.StalenessRequirements
  alias Citadel.TestSupport.ToxiproxyHarness
  alias Jido.Integration.V2.DerivedStateAttachment
  alias Jido.Integration.V2.EvidenceRef
  alias Jido.Integration.V2.GovernanceRef
  alias Jido.Integration.V2.SubjectRef

  @proxy_name "citadel_nginx"
  @timeout_key {__MODULE__, :proxy_timeout_ms}

  defmodule FaultInjectedDownstream do
    alias Citadel.TestSupport.ToxiproxyHarness

    def publish_review_projection(_projection, metadata) do
      timeout =
        :persistent_term.get(
          {Citadel.ProjectionBridgeInfrastructureFaultInjectionTest, :proxy_timeout_ms}
        )

      ToxiproxyHarness.request_url(
        :get,
        ToxiproxyHarness.proxy_url("/"),
        timeout: timeout,
        connect_timeout: timeout
      )
      |> ToxiproxyHarness.normalize_http_result("review:#{metadata.entry_id}")
    end

    def publish_derived_state_attachment(_attachment, metadata) do
      timeout =
        :persistent_term.get(
          {Citadel.ProjectionBridgeInfrastructureFaultInjectionTest, :proxy_timeout_ms}
        )

      ToxiproxyHarness.request_url(
        :get,
        ToxiproxyHarness.proxy_url("/"),
        timeout: timeout,
        connect_timeout: timeout
      )
      |> ToxiproxyHarness.normalize_http_result("attachment:#{metadata.entry_id}")
    end
  end

  setup do
    if wave12_enabled?() do
      case ToxiproxyHarness.availability_result!(
             "Citadel.ProjectionBridge Wave 12 fault injection"
           ) do
        :ok -> :ok
        {:skip, _reason} -> :ok
      end

      ToxiproxyHarness.ensure_proxy!()
      :persistent_term.put(@timeout_key, 500)
    end

    on_exit(fn ->
      if wave12_enabled?() do
        ToxiproxyHarness.ensure_proxy!()
      end

      :persistent_term.erase(@timeout_key)
    end)

    :ok
  end

  test "bandwidth starvation on review publication opens the circuit and then fast-fails" do
    run_wave12(fn ->
      :persistent_term.put(@timeout_key, 150)
      ToxiproxyHarness.add_toxic!(@proxy_name, "bandwidth", "bandwidth", %{"rate" => 1})

      bridge =
        ProjectionBridge.new!(
          downstream: FaultInjectedDownstream,
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

      observation = runtime_observation()

      {{:error, :timeout, bridge}, first_ms} =
        ToxiproxyHarness.measure_ms(fn ->
          ProjectionBridge.publish_review_projection(
            bridge,
            observation,
            outbox_entry("entry-review-1", "publish_projection")
          )
        end)

      assert first_ms >= 100

      {{:error, :timeout, bridge}, second_ms} =
        ToxiproxyHarness.measure_ms(fn ->
          ProjectionBridge.publish_review_projection(
            bridge,
            observation,
            outbox_entry("entry-review-2", "publish_projection")
          )
        end)

      assert second_ms >= 100

      {{:error, :circuit_open, _bridge}, third_ms} =
        ToxiproxyHarness.measure_ms(fn ->
          ProjectionBridge.publish_review_projection(
            bridge,
            observation,
            outbox_entry("entry-review-3", "publish_projection")
          )
        end)

      assert third_ms < 50
    end)
  end

  test "connection drops on derived-state publication surface explicitly and recover after reset" do
    run_wave12(fn ->
      bridge = ProjectionBridge.new!(downstream: FaultInjectedDownstream)
      attachment = derived_state_attachment()

      ToxiproxyHarness.set_enabled!(@proxy_name, false)

      {{:error, :connection_dropped, _bridge}, elapsed_ms} =
        ToxiproxyHarness.measure_ms(fn ->
          ProjectionBridge.publish_derived_state_attachment(
            bridge,
            attachment,
            outbox_entry("entry-attachment-drop", "publish_attachment")
          )
        end)

      assert elapsed_ms < 150

      ToxiproxyHarness.ensure_proxy!()

      {{:ok, "attachment:entry-attachment-recovered", _bridge}, recovered_ms} =
        ToxiproxyHarness.measure_ms(fn ->
          ProjectionBridge.publish_derived_state_attachment(
            bridge,
            attachment,
            outbox_entry("entry-attachment-recovered", "publish_attachment")
          )
        end)

      assert recovered_ms < 150
    end)
  end

  defp runtime_observation do
    RuntimeObservation.new!(%{
      observation_id: "obs-fault-1",
      request_id: "req-fault-1",
      session_id: "sess-fault-1",
      signal_id: "sig-fault-1",
      signal_cursor: "cursor-fault-1",
      runtime_ref_id: "runtime-fault-1",
      event_kind: "execution_event",
      event_at: ~U[2026-04-10 10:00:00Z],
      status: "ok",
      output: %{"result" => "done"},
      artifacts: [],
      payload: %{"phase" => "done"},
      subject_ref: SubjectRef.new!(%{kind: :run, id: "run-fault-1"}),
      evidence_refs: [
        EvidenceRef.new!(%{
          kind: :event,
          id: "event-fault-1",
          packet_ref: "packet-fault-1",
          subject: SubjectRef.new!(%{kind: :event, id: "event-fault-1"})
        })
      ],
      governance_refs: [
        GovernanceRef.new!(%{
          kind: :policy_decision,
          id: "governance-fault-1",
          subject: SubjectRef.new!(%{kind: :run, id: "run-fault-1"}),
          evidence: [],
          metadata: %{}
        })
      ],
      extensions: %{}
    })
  end

  defp derived_state_attachment do
    DerivedStateAttachment.new!(%{
      subject: SubjectRef.new!(%{kind: :run, id: "run-fault-1"}),
      evidence_refs: [
        EvidenceRef.new!(%{
          kind: :event,
          id: "event-fault-1",
          packet_ref: "packet-fault-1",
          subject: SubjectRef.new!(%{kind: :event, id: "event-fault-1"})
        })
      ],
      governance_refs: [],
      metadata: %{"kind" => "derived_summary"}
    })
  end

  defp outbox_entry(entry_id, action_kind) do
    ActionOutboxEntry.new!(%{
      schema_version: 1,
      entry_id: entry_id,
      causal_group_id: "group-fault-1",
      action:
        LocalAction.new!(%{
          action_kind: action_kind,
          payload: %{"entry_id" => entry_id},
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

  defp run_wave12(fun) when is_function(fun, 0) do
    if wave12_enabled?(), do: fun.(), else: :ok
  end

  defp wave12_enabled? do
    System.get_env("CITADEL_REQUIRE_TOXIPROXY") == "1"
  end
end
