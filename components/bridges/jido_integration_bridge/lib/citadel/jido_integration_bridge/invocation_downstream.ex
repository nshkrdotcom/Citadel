defmodule Citadel.JidoIntegrationBridge.InvocationDownstream do
  @moduledoc """
  Concrete downstream for `Citadel.InvocationBridge` that projects into the
  durable `BrainInvocation` packet and delegates transport.
  """

  @behaviour Citadel.InvocationBridge.Downstream

  alias Citadel.ExecutionIntentEnvelope.V2, as: ExecutionIntentEnvelopeV2
  alias Citadel.JidoIntegrationBridge
  alias Citadel.JidoIntegrationBridge.BrainInvocationAdapter
  alias Jido.Integration.V2.SubmissionAcceptance
  alias Jido.Integration.V2.SubmissionRejection

  @impl true
  def submit_execution_intent(%ExecutionIntentEnvelopeV2{} = envelope) do
    envelope
    |> BrainInvocationAdapter.project!()
    |> JidoIntegrationBridge.transport_module().submit_brain_invocation()
    |> normalize_result()
  end

  defp normalize_result({:accepted, %SubmissionAcceptance{} = acceptance}),
    do: {:accepted, acceptance}

  defp normalize_result({:rejected, %SubmissionRejection{} = rejection}),
    do: {:rejected, rejection}

  defp normalize_result({:error, reason}) when is_atom(reason), do: {:error, reason}
  defp normalize_result(_other), do: {:error, :invalid_transport_result}
end
