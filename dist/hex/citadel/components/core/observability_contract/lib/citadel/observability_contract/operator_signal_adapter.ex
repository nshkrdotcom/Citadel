defmodule Citadel.ObservabilityContract.OperatorSignalAdapter do
  @moduledoc """
  Backend envelopes for operator-facing metrics, logs, and trace spans.

  This module does not emit AITrace audit records. It shapes data that runtime
  owners can send to telemetry, logging, and tracing backends.
  """

  alias Citadel.ObservabilityContract.OperationalSignal

  @spec backend_envelopes(OperationalSignal.t() | map() | keyword()) :: map()
  def backend_envelopes(%OperationalSignal{} = signal) do
    %{
      telemetry: telemetry_envelope(signal),
      metric: metric_envelope(signal),
      log: log_envelope(signal),
      trace: trace_envelope(signal)
    }
  end

  def backend_envelopes(attrs), do: attrs |> OperationalSignal.new!() |> backend_envelopes()

  @spec telemetry_envelope(OperationalSignal.t()) :: map()
  def telemetry_envelope(%OperationalSignal{} = signal) do
    %{
      backend: :telemetry,
      event_name: signal.telemetry_event,
      measurements: signal.measurements,
      metadata: signal.metric_labels
    }
  end

  @spec metric_envelope(OperationalSignal.t()) :: map()
  def metric_envelope(%OperationalSignal{} = signal) do
    %{
      backend: :metric,
      metric_ref: signal.metric_ref,
      labels: signal.metric_labels,
      measurements: signal.measurements
    }
  end

  @spec log_envelope(OperationalSignal.t()) :: map()
  def log_envelope(%OperationalSignal{} = signal) do
    %{
      backend: :log,
      log_ref: signal.log_ref,
      fields: signal.log_fields,
      redaction_policy_ref: signal.redaction_policy_ref
    }
  end

  @spec trace_envelope(OperationalSignal.t()) :: map()
  def trace_envelope(%OperationalSignal{} = signal) do
    %{
      backend: :trace,
      trace_ref: signal.trace_ref,
      attributes: signal.trace_attributes,
      redaction_policy_ref: signal.redaction_policy_ref
    }
  end
end
