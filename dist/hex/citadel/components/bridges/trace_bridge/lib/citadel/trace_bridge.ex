defmodule Citadel.TraceBridge do
  @moduledoc """
  AITrace-facing trace publication bridge consuming canonical `Citadel.TraceEnvelope` values.
  """

  alias Citadel.ObservabilityContract.Trace, as: TraceContract
  alias Citadel.TraceEnvelope

  @behaviour Citadel.Ports.Trace

  @manifest %{
    package: :citadel_trace_bridge,
    layer: :bridge,
    status: :wave_5_contract_frozen,
    owns: [:trace_publication, :aitrace_translation, :stable_failure_codes],
    internal_dependencies: [:citadel_core, :citadel_runtime, :citadel_observability_contract],
    external_dependencies: [:aitrace]
  }

  @type reason_code ::
          :unavailable | :timeout | :rate_limited | :invalid_envelope | :backend_rejected | :circuit_open | :unknown

  @impl true
  @spec publish_trace(TraceEnvelope.t()) :: :ok | {:error, reason_code()}
  def publish_trace(%TraceEnvelope{} = envelope) do
    with {:ok, normalized_envelope} <- TraceEnvelope.new(envelope) do
      adapter().publish_trace(normalized_envelope)
    else
      {:error, _error} -> {:error, :invalid_envelope}
    end
  end

  def publish_trace(_other), do: {:error, :invalid_envelope}

  @impl true
  @spec publish_traces([TraceEnvelope.t()]) :: :ok | {:error, reason_code()}
  def publish_traces(envelopes) when is_list(envelopes) do
    with {:ok, normalized_envelopes} <- normalize_envelopes(envelopes) do
      adapter().publish_traces(normalized_envelopes)
    end
  end

  def publish_traces(_other), do: {:error, :invalid_envelope}

  @spec export_targets() :: [atom()]
  def export_targets, do: [:aitrace]

  @spec failure_reason_codes() :: [atom(), ...]
  def failure_reason_codes, do: TraceContract.failure_reason_codes()

  @spec manifest() :: map()
  def manifest, do: @manifest

  defp adapter do
    Application.get_env(:citadel_trace_bridge, :adapter, Citadel.TraceBridge.AITraceAdapter)
  end

  defp normalize_envelopes(envelopes) do
    Enum.reduce_while(envelopes, {:ok, []}, fn
      %TraceEnvelope{} = envelope, {:ok, acc} ->
        case TraceEnvelope.new(envelope) do
          {:ok, normalized_envelope} ->
            {:cont, {:ok, [normalized_envelope | acc]}}

          {:error, _error} ->
            {:halt, {:error, :invalid_envelope}}
        end

      _other, _acc ->
        {:halt, {:error, :invalid_envelope}}
    end)
    |> case do
      {:ok, normalized_envelopes} -> {:ok, Enum.reverse(normalized_envelopes)}
      {:error, :invalid_envelope} = error -> error
    end
  end
end
