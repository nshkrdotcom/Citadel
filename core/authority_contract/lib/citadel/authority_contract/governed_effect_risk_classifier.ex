defmodule Citadel.AuthorityContract.GovernedEffectRiskClassifier do
  @moduledoc """
  Bounded risk classification for governed-effect authority requests.
  """

  alias Citadel.AuthorityContract.GovernedEffectAuthorityRequest

  @risk_classes [:low, :medium, :high, :critical]

  @type classification :: %{
          required(:risk_class) => atom(),
          required(:review_required?) => boolean(),
          required(:compensation_required?) => boolean(),
          required(:reason) => String.t()
        }

  @spec risk_classes() :: [atom()]
  def risk_classes, do: @risk_classes

  @spec classify!(GovernedEffectAuthorityRequest.t() | map() | keyword()) :: classification()
  def classify!(request) do
    request = GovernedEffectAuthorityRequest.new!(request)

    classification =
      case {request.effect_type, request.side_effect_class} do
        {"diagnostic.probe", "external_call"} ->
          {:medium, true, false, "diagnostic_external_probe"}

        {"diagnostic", _side_effect_class} ->
          {:low, false, false, "diagnostic"}

        {"diagnostic.echo", _side_effect_class} ->
          {:low, false, false, "diagnostic_echo"}

        {"diagnostic.probe", _side_effect_class} ->
          {:low, false, false, "diagnostic_probe"}

        {"read_only", _side_effect_class} ->
          {:low, false, false, "read_only"}

        {"write", _side_effect_class} ->
          {:high, true, true, "write_effect"}

        {"delete", _side_effect_class} ->
          {:critical, true, true, "delete_effect"}

        {"external_call", _side_effect_class} ->
          {:medium, true, false, "external_call"}

        {_unknown, _side_effect_class} ->
          {:high, true, true, "unknown_effect_type"}
      end

    to_map(classification)
  end

  @spec classify(GovernedEffectAuthorityRequest.t() | map() | keyword()) ::
          {:ok, classification()} | {:error, Exception.t()}
  def classify(request) do
    {:ok, classify!(request)}
  rescue
    error in ArgumentError -> {:error, error}
  end

  defp to_map({risk_class, review_required?, compensation_required?, reason}) do
    %{
      risk_class: risk_class,
      review_required?: review_required?,
      compensation_required?: compensation_required?,
      reason: reason
    }
  end
end
