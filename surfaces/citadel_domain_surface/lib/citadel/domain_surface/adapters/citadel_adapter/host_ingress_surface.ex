defmodule Citadel.DomainSurface.Adapters.CitadelAdapter.HostIngressSurface do
  @moduledoc false

  @behaviour Citadel.DomainSurface.Adapters.CitadelAdapter.RequestSubmission

  alias Citadel.HostIngress
  alias Citadel.HostIngress.RequestContext, as: HostIngressRequestContext
  alias Citadel.DomainSurface.Adapters.CitadelAdapter.RequestContext

  @builder_option_keys [
    :host_ingress,
    :host_ingress_opts,
    :session_directory,
    :policy_packs,
    :lookup_session,
    :clock,
    :command_name
  ]

  @spec submit_envelope(Citadel.IntentEnvelope.t(), RequestContext.t(), keyword()) ::
          Citadel.DomainSurface.Adapters.CitadelAdapter.RequestSubmission.submission_result()
  @impl true
  def submit_envelope(envelope, %RequestContext{} = request_context, opts)
      when is_list(opts) do
    host_ingress = host_ingress(opts)
    host_request_context = host_request_context(request_context)

    HostIngress.submit_envelope(
      host_ingress,
      envelope,
      host_request_context,
      submission_opts(opts)
    )
  rescue
    error in ArgumentError -> {:error, {:invalid_host_ingress_surface, Exception.message(error)}}
  end

  defp host_ingress(opts) do
    case Keyword.get(opts, :host_ingress) do
      %HostIngress{} = host_ingress ->
        host_ingress

      nil ->
        host_ingress_opts =
          opts
          |> Keyword.get(:host_ingress_opts, [])
          |> Keyword.merge(
            session_directory: Keyword.get(opts, :session_directory),
            policy_packs: Keyword.get(opts, :policy_packs),
            lookup_session: Keyword.get(opts, :lookup_session),
            clock: Keyword.get(opts, :clock)
          )
          |> Enum.reject(fn {_key, value} -> is_nil(value) end)

        HostIngress.new!(host_ingress_opts)

      other ->
        raise ArgumentError,
              "citadel host_ingress_surface :host_ingress must be a Citadel.HostIngress struct, got: #{inspect(other)}"
    end
  end

  defp host_request_context(%RequestContext{} = request_context) do
    HostIngressRequestContext.new!(%{
      request_id: request_context.request_id,
      session_id: request_context.session_id,
      tenant_id: request_context.tenant_id,
      actor_id: request_context.actor_id,
      trace_id: request_context.trace_id,
      trace_origin: request_context.trace_origin,
      idempotency_key: request_context.idempotency_key,
      host_request_id: request_context.host_request_id,
      environment: request_context.environment,
      policy_epoch: request_context.policy_epoch,
      metadata_keys: request_context.metadata_keys
    })
  end

  defp submission_opts(opts), do: Keyword.drop(opts, @builder_option_keys)
end
