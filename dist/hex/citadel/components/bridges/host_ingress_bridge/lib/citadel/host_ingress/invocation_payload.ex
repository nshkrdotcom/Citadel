defmodule Citadel.HostIngress.InvocationPayload do
  @moduledoc """
  Canonical outbox payload codec for `submit_invocation` host-ingress entries.
  """

  alias Citadel.InvocationRequest.V2, as: InvocationRequestV2

  @action_kind "submit_invocation"

  @spec action_kind() :: String.t()
  def action_kind, do: @action_kind

  @spec encode!(InvocationRequestV2.t()) :: map()
  def encode!(%InvocationRequestV2{} = request) do
    %{
      "request_id" => request.request_id,
      "invocation_request_id" => request.invocation_request_id,
      "invocation_request" => InvocationRequestV2.dump(request)
    }
  end

  @spec decode!(map() | keyword()) :: InvocationRequestV2.t()
  def decode!(payload) do
    payload = Map.new(payload)

    case Map.get(payload, "invocation_request", Map.get(payload, :invocation_request)) do
      nil ->
        raise ArgumentError,
              "host ingress invocation payload requires invocation_request"

      invocation_request ->
        InvocationRequestV2.new!(invocation_request)
    end
  end
end
