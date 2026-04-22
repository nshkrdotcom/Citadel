defmodule Citadel.TraceBridgeTest do
  use ExUnit.Case, async: true

  alias AITrace.Span
  alias Citadel.TraceBridge
  alias Citadel.TraceEnvelope

  defmodule TestExporter do
    @behaviour AITrace.Exporter

    @impl true
    def init(opts), do: {:ok, opts}

    @impl true
    def export(trace, state) do
      send(state.test_pid, {:exported_trace, trace})
      {:ok, state}
    end

    @impl true
    def shutdown(_state), do: :ok
  end

  setup do
    previous_exporters = Application.get_env(:aitrace, :exporters)
    Application.put_env(:aitrace, :exporters, [{TestExporter, test_pid: self()}])
    on_exit(fn -> Application.put_env(:aitrace, :exporters, previous_exporters) end)
    :ok
  end

  test "translates event envelopes into AITrace traces" do
    envelope =
      TraceEnvelope.new!(%{
        trace_envelope_id: "env-1",
        record_kind: :event,
        family: "session_attached",
        name: "citadel.session.attached",
        phase: "post_commit",
        trace_id: "trace-1",
        tenant_id: "tenant-1",
        session_id: "sess-1",
        request_id: "req-1",
        decision_id: nil,
        snapshot_seq: 1,
        signal_id: nil,
        outbox_entry_id: nil,
        boundary_ref: "boundary-ref-1",
        span_id: nil,
        parent_span_id: nil,
        occurred_at: ~U[2026-04-10 10:00:00Z],
        started_at: nil,
        finished_at: nil,
        status: "ok",
        attributes: %{"attach_mode" => "fresh_or_reuse"},
        extensions: %{
          "canonical_idempotency_key" => "idem:v1:session-attached",
          "platform_envelope_id" => "intent-session-attached"
        }
      })

    assert :ok = TraceBridge.publish_trace(envelope)
    assert_receive {:exported_trace, trace}
    assert trace.trace_id == "trace-1"
    assert trace.trace_id_source.kind == :external_alias
    assert trace.created_at == nil
    assert trace.created_at_wall_time == ~U[2026-04-10 10:00:00Z]
    assert trace.clock_domain.source == "citadel_trace_envelope"
    assert trace.metadata.lineage.trace_id == "trace-1"
    assert trace.metadata.lineage.tenant_id == "tenant-1"
    assert trace.metadata.lineage.causation_id == "req-1"
    assert trace.metadata.lineage.canonical_idempotency_key == "idem:v1:session-attached"
    assert trace.metadata.platform_envelope_field_map.trace_id == "AITrace.Trace.trace_id"

    assert trace.metadata.platform_envelope_field_map.request_id ==
             "AITrace.Context.metadata.causation_id"

    assert [%Span{name: "citadel.event", events: [event]}] = trace.spans
    assert hd(trace.spans).span_id_source.kind == :external_alias
    assert hd(trace.spans).start_time == nil
    assert hd(trace.spans).start_wall_time == ~U[2026-04-10 10:00:00Z]
    assert hd(trace.spans).clock_domain.source == "citadel_trace_envelope"
    assert event.name == "citadel.session.attached"
    assert event.timestamp == nil
    assert event.wall_time == ~U[2026-04-10 10:00:00Z]
    assert event.clock_domain.source == "citadel_trace_envelope"
    assert event.attributes["attach_mode"] == "fresh_or_reuse"
  end

  test "translates completed spans without inventing an open-span API" do
    envelope =
      TraceEnvelope.new!(%{
        trace_envelope_id: "env-2",
        record_kind: :span,
        family: "decision_task",
        name: "citadel.span.decision_task",
        phase: "post_commit",
        trace_id: "trace-2",
        tenant_id: "tenant-1",
        session_id: "sess-1",
        request_id: "req-1",
        decision_id: "dec-1",
        snapshot_seq: 1,
        signal_id: nil,
        outbox_entry_id: nil,
        boundary_ref: nil,
        span_id: "span-1",
        parent_span_id: "parent-span-1",
        occurred_at: nil,
        started_at: ~U[2026-04-10 10:00:00Z],
        finished_at: ~U[2026-04-10 10:00:01Z],
        status: "ok",
        attributes: %{"duration_bucket" => "fast"},
        extensions: %{"canonical_idempotency_key" => "idem:v1:decision-task"}
      })

    assert :ok = TraceBridge.publish_trace(envelope)
    assert_receive {:exported_trace, trace}

    assert [
             %Span{
               name: "citadel.span.decision_task",
               span_id: "span-1",
               span_id_source: %{kind: :external_alias},
               parent_span_id: "parent-span-1",
               parent_span_id_source: %{kind: :external_alias},
               start_time: nil,
               end_time: nil,
               start_wall_time: ~U[2026-04-10 10:00:00Z],
               end_wall_time: ~U[2026-04-10 10:00:01Z]
             }
           ] = trace.spans

    assert trace.metadata.aitrace_context.trace_id == "trace-2"
    assert trace.metadata.aitrace_context.span_id == "span-1"
    assert trace.metadata.platform_envelope_field_map.span_id == "AITrace.Context.span_id"
  end

  test "returns stable invalid_envelope errors for malformed payloads" do
    assert {:error, :invalid_envelope} =
             TraceBridge.publish_trace(%{
               trace_envelope_id: "env-3",
               record_kind: :event,
               family: "session_attached",
               name: "citadel.session.attached",
               phase: "post_commit",
               trace_id: "trace-3",
               tenant_id: "tenant-1",
               session_id: "sess-1",
               request_id: "req-1",
               decision_id: nil,
               snapshot_seq: 1,
               signal_id: nil,
               outbox_entry_id: nil,
               boundary_ref: nil,
               span_id: nil,
               parent_span_id: nil,
               occurred_at: nil,
               started_at: nil,
               finished_at: nil,
               status: "ok",
               attributes: %{},
               extensions: %{}
             })
  end
end
