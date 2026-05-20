defmodule Citadel.AuthorityContract.GovernedEffectAuthority do
  @moduledoc """
  Minimal governed-effect authority compiler.

  This phase emits `AuthorityDecision.v1` with governed-effect facts inside the
  Citadel extension namespace because the V1 packet field inventory is frozen.
  """

  alias Citadel.AuthorityContract.AuthorityDecision.V1, as: AuthorityDecisionV1
  alias Citadel.AuthorityContract.GovernedEffectAuthorityRequest
  alias Citadel.AuthorityContract.GovernedEffectRiskClassifier
  alias Citadel.ContractCore.CanonicalJson

  @allowed_diagnostic_effect_types ["diagnostic", "diagnostic.echo", "diagnostic.probe"]
  @policy_version "diagnostic-lane-2026-05-20"

  @spec allowed_diagnostic_effect_types() :: [String.t()]
  def allowed_diagnostic_effect_types, do: @allowed_diagnostic_effect_types

  @spec authorize(GovernedEffectAuthorityRequest.t() | map() | keyword(), keyword()) ::
          {:ok, AuthorityDecisionV1.t()} | {:error, Exception.t()}
  def authorize(request, opts \\ []) do
    request = GovernedEffectAuthorityRequest.new!(request)
    {:ok, build_decision(request, opts)}
  rescue
    error in ArgumentError -> {:error, error}
  end

  @spec authorize!(GovernedEffectAuthorityRequest.t() | map() | keyword(), keyword()) ::
          AuthorityDecisionV1.t()
  def authorize!(request, opts \\ []) do
    case authorize(request, opts) do
      {:ok, decision} -> decision
      {:error, error} -> raise error
    end
  end

  defp build_decision(%GovernedEffectAuthorityRequest{} = request, opts) do
    allowed_effect_types =
      Keyword.get(opts, :allowed_effect_types, @allowed_diagnostic_effect_types)

    risk = GovernedEffectRiskClassifier.classify!(request)
    allowed? = request.effect_type in allowed_effect_types
    decision = if allowed?, do: "allow", else: "deny"

    %{
      contract_version: AuthorityDecisionV1.contract_version(),
      decision_id: decision_id(request),
      tenant_id: request.tenant_ref,
      request_id: request_id(request),
      policy_version: Keyword.get(opts, :policy_version, @policy_version),
      boundary_class: "diagnostic",
      trust_profile: "diagnostic_trusted",
      approval_profile: approval_profile(decision, risk),
      egress_profile: "localhost_only",
      workspace_profile: "read_only",
      resource_profile: "diagnostic_lane",
      decision_hash: String.duplicate("0", 64),
      extensions: %{
        "citadel" => %{
          "for_action_ref" => request.effect_ref || request.request_ref,
          "governed_effect" =>
            governed_effect_extension(request, allowed_effect_types, risk, decision)
        }
      }
    }
    |> put_decision_hash()
  end

  defp approval_profile("deny", _risk), do: "denied"
  defp approval_profile(_decision, %{review_required?: true}), do: "review_required"
  defp approval_profile(_decision, _risk), do: "auto"

  defp governed_effect_extension(request, allowed_effect_types, risk, decision) do
    %{
      "decision" => decision,
      "effect_ref" => request.effect_ref,
      "effect_type" => request.effect_type,
      "effect_type_allowed" => allowed_effect_types,
      "effect_risk_class" => Atom.to_string(risk.risk_class),
      "compensation_required" => risk.compensation_required?,
      "review_required_for_effect" => risk.review_required?,
      "risk_reason" => risk.reason
    }
    |> maybe_put(
      "denial_reason",
      denial_reason(decision, request.effect_type, allowed_effect_types)
    )
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp denial_reason("deny", effect_type, allowed_effect_types) do
    if effect_type in allowed_effect_types do
      "policy_denied"
    else
      "effect_type_not_allowed"
    end
  end

  defp denial_reason(_decision, _effect_type, _allowed_effect_types), do: nil

  defp decision_id(%GovernedEffectAuthorityRequest{} = request) do
    case request.request_ref do
      request_ref when is_binary(request_ref) and request_ref != "" ->
        String.replace(request_ref, "authority-request://", "authority-decision://")

      _missing ->
        "authority-decision://governed-effect/" <> request.tenant_ref
    end
  end

  defp request_id(%GovernedEffectAuthorityRequest{request_ref: request_ref})
       when is_binary(request_ref) and request_ref != "",
       do: request_ref

  defp request_id(%GovernedEffectAuthorityRequest{effect_ref: effect_ref})
       when is_binary(effect_ref) and effect_ref != "",
       do: effect_ref

  defp request_id(%GovernedEffectAuthorityRequest{} = request),
    do: "governed-effect-request://" <> request.tenant_ref

  defp put_decision_hash(attrs) do
    pending = AuthorityDecisionV1.new!(attrs)
    hash = pending |> AuthorityDecisionV1.hash_payload() |> canonical_sha256()

    attrs
    |> Map.put(:decision_hash, hash)
    |> AuthorityDecisionV1.new!()
  end

  defp canonical_sha256(payload) do
    payload
    |> CanonicalJson.encode_inline!(
      max_bytes: 1_000_000,
      label: "AuthorityDecision.v1 hash input"
    )
    |> sha256_lower_hex()
  end

  defp sha256_lower_hex(value) when is_binary(value) do
    :sha256
    |> :crypto.hash(value)
    |> Base.encode16(case: :lower)
  end
end
