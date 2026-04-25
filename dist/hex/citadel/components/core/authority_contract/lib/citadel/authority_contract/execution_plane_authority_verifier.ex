defmodule Citadel.AuthorityContract.ExecutionPlaneAuthorityVerifier do
  @moduledoc """
  Citadel authority verifier for the Execution Plane node boundary.

  The node registers this module through the root
  `ExecutionPlane.Authority.Verifier` behaviour. The verifier checks that the
  opaque authority reference carries the Citadel decision identity and a
  policy-bundle hash; it does not make routing or sandbox decisions.
  """

  @behaviour ExecutionPlane.Authority.Verifier

  alias ExecutionPlane.Admission.Rejection
  alias ExecutionPlane.Authority.Ref

  @impl true
  def verifier_id, do: "citadel-authority-decision-v1"

  @impl true
  def verify(%Ref{} = authority_ref, opts) do
    with :ok <- validate_ref(authority_ref),
         :ok <- validate_audience(authority_ref, Keyword.get(opts, :audience)),
         :ok <- validate_expiry(authority_ref, Keyword.get(opts, :now_ms)) do
      {:ok,
       %{
         verifier_id: verifier_id(),
         authority_ref: authority_ref.ref,
         decision_id: authority_ref.metadata["decision_id"],
         policy_version: authority_ref.metadata["policy_version"],
         decision_hash: authority_ref.metadata["decision_hash"],
         payload_hash: authority_ref.payload_hash
       }}
    end
  end

  def verify(authority_ref, opts) when is_map(authority_ref) or is_list(authority_ref) do
    authority_ref
    |> Ref.new!()
    |> verify(opts)
  rescue
    error in ArgumentError ->
      {:error, Rejection.new(:invalid_authority_ref, Exception.message(error))}
  end

  def verify(authority_ref, _opts) do
    {:error,
     Rejection.new(
       :invalid_authority_ref,
       "expected ExecutionPlane.Authority.Ref, got: #{inspect(authority_ref)}"
     )}
  end

  defp validate_ref(%Ref{} = authority_ref) do
    cond do
      blank?(authority_ref.ref) ->
        reject(:invalid_authority_ref, "authority ref is required")

      blank?(authority_ref.payload_hash) ->
        reject(:invalid_authority_ref, "authority payload_hash is required")

      blank?(authority_ref.metadata["decision_id"]) ->
        reject(:invalid_authority_ref, "authority metadata decision_id is required")

      blank?(authority_ref.metadata["policy_version"]) ->
        reject(:invalid_authority_ref, "authority metadata policy_version is required")

      blank?(authority_ref.metadata["decision_hash"]) ->
        reject(:invalid_authority_ref, "authority metadata decision_hash is required")

      true ->
        :ok
    end
  end

  defp validate_audience(_authority_ref, nil), do: :ok

  defp validate_audience(%Ref{audience: audience}, expected_audience)
       when audience == expected_audience,
       do: :ok

  defp validate_audience(%Ref{audience: audience}, expected_audience) do
    reject(
      :authority_audience_mismatch,
      "authority audience #{inspect(audience)} does not match #{inspect(expected_audience)}"
    )
  end

  defp validate_expiry(_authority_ref, nil), do: :ok

  defp validate_expiry(%Ref{expires_at: nil}, _now_ms), do: :ok

  defp validate_expiry(%Ref{expires_at: expires_at}, now_ms)
       when is_integer(expires_at) and is_integer(now_ms) and expires_at >= now_ms,
       do: :ok

  defp validate_expiry(%Ref{expires_at: expires_at}, now_ms) do
    reject(
      :authority_expired,
      "authority expired at #{inspect(expires_at)} before #{inspect(now_ms)}"
    )
  end

  defp reject(reason, message), do: {:error, Rejection.new(reason, message)}

  defp blank?(value), do: !is_binary(value) or String.trim(value) == ""
end
