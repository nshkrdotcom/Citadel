defmodule Citadel.Runtime.TracePublisherTest do
  use ExUnit.Case, async: false

  alias Citadel.Runtime.TracePublisher

  defmodule NoopTracePort do
    @behaviour Citadel.Ports.Trace

    @impl true
    def publish_trace(_envelope), do: :ok

    @impl true
    def publish_traces(_envelopes), do: :ok
  end

  defmodule FailingTracePort do
    @behaviour Citadel.Ports.Trace

    @impl true
    def publish_trace(_envelope), do: {:error, :unavailable}

    @impl true
    def publish_traces(_envelopes), do: {:error, :unavailable}
  end

  test "buffer overflow preserves the protected error-family evidence window and emits dropped-family telemetry" do
    attach_telemetry(self())
    publisher = start_trace_publisher(trace_port: NoopTracePort, buffer_capacity: 4, protected_error_capacity: 2, flush_interval_ms: 1_000, batch_size: 4)

    assert :ok = TracePublisher.publish_trace(publisher, regular_envelope("env-1", "session_attached"))
    assert :ok = TracePublisher.publish_trace(publisher, regular_envelope("env-2", "signal_normalized"))
    assert :ok = TracePublisher.publish_trace(publisher, protected_envelope("env-3", "session_blocked"))
    assert :ok = TracePublisher.publish_trace(publisher, protected_envelope("env-4", "session_crash_recovery_triggered"))
    assert :ok = TracePublisher.publish_trace(publisher, regular_envelope("env-5", "session_resumed"))

    assert TracePublisher.snapshot(publisher) == %{depth: 4, protected_depth: 2, regular_depth: 2}

    assert_receive {:telemetry, [:citadel, :trace, :publish, :drop], %{count: 1},
                    %{dropped_family: "session_attached", dropped_family_classification: :default}}

    assert_receive {:telemetry, [:citadel, :trace, :buffer, :depth],
                    %{depth: 4, protected_depth: 2, regular_depth: 2}, %{}}
  end

  test "publication failures emit low-cardinality telemetry without blocking the caller" do
    attach_telemetry(self())
    publisher = start_trace_publisher(trace_port: FailingTracePort, buffer_capacity: 2, protected_error_capacity: 1, flush_interval_ms: 0, batch_size: 1)

    assert :ok = TracePublisher.publish_trace(publisher, regular_envelope("env-fail", "session_attached"))

    assert_receive {:telemetry, [:citadel, :trace, :publish, :failure], %{count: 1, batch_size: 1},
                    %{reason_code: :unavailable}}
  end

  defp start_trace_publisher(opts) do
    name = :"trace_publisher_#{System.unique_integer([:positive])}"
    start_supervised!({TracePublisher, Keyword.put(opts, :name, name)})
  end

  defp attach_telemetry(test_pid) do
    handler_id = "trace-publisher-test-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      [
        [:citadel, :trace, :buffer, :depth],
        [:citadel, :trace, :publish, :drop],
        [:citadel, :trace, :publish, :failure]
      ],
      fn event, measurements, metadata, pid ->
        send(pid, {:telemetry, event, measurements, metadata})
      end,
      test_pid
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end

  defp regular_envelope(id, family) do
    %{
      trace_envelope_id: id,
      record_kind: :event,
      family: family,
      name: canonical_name(family),
      phase: "post_commit",
      trace_id: "trace-1",
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
      occurred_at: ~U[2026-04-10 10:00:00Z],
      started_at: nil,
      finished_at: nil,
      status: "ok",
      attributes: %{},
      extensions: %{}
    }
  end

  defp protected_envelope(id, family) do
    regular_envelope(id, family)
  end

  defp canonical_name("session_attached"), do: "citadel.session.attached"
  defp canonical_name("signal_normalized"), do: "citadel.signal.normalized"
  defp canonical_name("session_resumed"), do: "citadel.session.resumed"
  defp canonical_name("session_blocked"), do: "citadel.session.blocked"
  defp canonical_name("session_crash_recovery_triggered"), do: "citadel.session.crash_recovery_triggered"
end
