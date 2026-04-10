defmodule Citadel.TraceBridge.AITraceAdapter do
  @moduledoc false

  alias AITrace.Event
  alias AITrace.Span
  alias AITrace.Trace
  alias Citadel.TraceEnvelope

  @spec publish_trace(TraceEnvelope.t()) :: :ok | {:error, atom()}
  def publish_trace(%TraceEnvelope{} = envelope) do
    envelope
    |> to_trace()
    |> export_trace()
  end

  @spec publish_traces([TraceEnvelope.t()]) :: :ok | {:error, atom()}
  def publish_traces(envelopes) when is_list(envelopes) do
    Enum.reduce_while(envelopes, :ok, fn envelope, :ok ->
      case publish_trace(envelope) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp export_trace(%Trace{} = trace) do
    exporters = Application.get_env(:aitrace, :exporters, [])

    if exporters == [] do
      {:error, :unavailable}
    else
      Enum.reduce_while(exporters, :ok, fn exporter_config, :ok ->
        with {:ok, exporter_module, opts} <- normalize_exporter(exporter_config),
             {:ok, state} <- normalize_result(exporter_module.init(opts)),
             {:ok, _state} <- normalize_result(exporter_module.export(trace, state)) do
          maybe_shutdown(exporter_module, state)
          {:cont, :ok}
        else
          {:error, reason} ->
            {:halt, {:error, map_error_reason(reason)}}
        end
      end)
    end
  end

  defp normalize_exporter({exporter_module, opts}) when is_atom(exporter_module) do
    {:ok, exporter_module, Map.new(opts)}
  end

  defp normalize_exporter(exporter_module) when is_atom(exporter_module) do
    {:ok, exporter_module, %{}}
  end

  defp normalize_exporter(_other), do: {:error, :backend_rejected}

  defp normalize_result({:ok, state}), do: {:ok, state}
  defp normalize_result({:error, reason}), do: {:error, reason}
  defp normalize_result(_other), do: {:error, :backend_rejected}

  defp maybe_shutdown(module, state) do
    if function_exported?(module, :shutdown, 1) do
      module.shutdown(state)
    end
  end

  defp to_trace(%TraceEnvelope{record_kind: :event} = envelope) do
    timestamp_us = datetime_to_microseconds(envelope.occurred_at)

    synthetic_span = %Span{
      span_id: envelope.span_id || "event-span:#{envelope.trace_envelope_id}",
      parent_span_id: envelope.parent_span_id,
      name: "citadel.event",
      start_time: timestamp_us,
      end_time: timestamp_us,
      attributes: %{
        family: envelope.family,
        phase: envelope.phase,
        record_kind: "event"
      },
      events: [
        %Event{
          name: envelope.name,
          timestamp: timestamp_us,
          attributes: event_attributes(envelope)
        }
      ],
      status: span_status(envelope.status)
    }

    %Trace{
      trace_id: envelope.trace_id,
      created_at: timestamp_us,
      spans: [synthetic_span],
      metadata: trace_metadata(envelope)
    }
  end

  defp to_trace(%TraceEnvelope{record_kind: :span} = envelope) do
    %Trace{
      trace_id: envelope.trace_id,
      created_at: datetime_to_microseconds(envelope.started_at),
      spans: [
        %Span{
          span_id: envelope.span_id || "span:#{envelope.trace_envelope_id}",
          parent_span_id: envelope.parent_span_id,
          name: envelope.name,
          start_time: datetime_to_microseconds(envelope.started_at),
          end_time: datetime_to_microseconds(envelope.finished_at),
          attributes: span_attributes(envelope),
          events: [],
          status: span_status(envelope.status)
        }
      ],
      metadata: trace_metadata(envelope)
    }
  end

  defp trace_metadata(%TraceEnvelope{} = envelope) do
    %{
      family: envelope.family,
      phase: envelope.phase,
      record_kind: Atom.to_string(envelope.record_kind),
      trace_envelope_id: envelope.trace_envelope_id,
      tenant_id: envelope.tenant_id,
      session_id: envelope.session_id,
      request_id: envelope.request_id,
      decision_id: envelope.decision_id,
      snapshot_seq: envelope.snapshot_seq,
      signal_id: envelope.signal_id,
      outbox_entry_id: envelope.outbox_entry_id,
      boundary_ref: envelope.boundary_ref
    }
    |> Map.merge(envelope.extensions)
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp event_attributes(%TraceEnvelope{} = envelope) do
    %{
      family: envelope.family,
      phase: envelope.phase,
      status: envelope.status,
      tenant_id: envelope.tenant_id,
      session_id: envelope.session_id,
      request_id: envelope.request_id,
      decision_id: envelope.decision_id,
      snapshot_seq: envelope.snapshot_seq,
      signal_id: envelope.signal_id,
      outbox_entry_id: envelope.outbox_entry_id,
      boundary_ref: envelope.boundary_ref
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
    |> Map.merge(envelope.attributes)
  end

  defp span_attributes(%TraceEnvelope{} = envelope) do
    %{
      family: envelope.family,
      phase: envelope.phase,
      tenant_id: envelope.tenant_id,
      session_id: envelope.session_id,
      request_id: envelope.request_id,
      decision_id: envelope.decision_id,
      snapshot_seq: envelope.snapshot_seq,
      signal_id: envelope.signal_id,
      outbox_entry_id: envelope.outbox_entry_id,
      boundary_ref: envelope.boundary_ref
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
    |> Map.merge(envelope.attributes)
  end

  defp datetime_to_microseconds(%DateTime{} = datetime), do: DateTime.to_unix(datetime, :microsecond)

  defp span_status(nil), do: :ok
  defp span_status("ok"), do: :ok
  defp span_status("success"), do: :ok
  defp span_status(_status), do: :error

  defp map_error_reason(:timeout), do: :timeout
  defp map_error_reason(:rate_limited), do: :rate_limited
  defp map_error_reason(:backend_rejected), do: :backend_rejected
  defp map_error_reason(:unavailable), do: :unavailable
  defp map_error_reason(_other), do: :unknown
end
