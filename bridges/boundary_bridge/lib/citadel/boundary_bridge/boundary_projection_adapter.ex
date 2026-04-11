defmodule Citadel.BoundaryBridge.BoundaryProjectionAdapter do
  @moduledoc """
  Isolates the boundary-intent projection shape at the bridge edge.
  """

  alias Citadel.AuthorityContract.AuthorityDecision.V1, as: AuthorityDecisionV1
  alias Citadel.BoundaryIntent
  alias Citadel.ContractCore.CanonicalJson

  @type metadata :: Citadel.Ports.BoundaryLifecycle.boundary_intent_metadata()
  @type projection :: %{required(String.t()) => CanonicalJson.value()}

  @spec project!(BoundaryIntent.t(), metadata()) :: projection()
  def project!(%BoundaryIntent{} = boundary_intent, metadata) when is_map(metadata) do
    session_id = fetch_required_string!(metadata, :session_id)
    tenant_id = fetch_required_string!(metadata, :tenant_id)
    target_id = fetch_required_string!(metadata, :target_id)
    authority_packet = fetch_optional_authority_packet(metadata)

    %{
      "boundary_intent" => normalize_projection_value!(BoundaryIntent.dump(boundary_intent)),
      "authority_packet" => normalize_optional_projection_value(authority_packet),
      "session_id" => session_id,
      "tenant_id" => tenant_id,
      "target_id" => target_id,
      "downstream_scope" =>
        fetch_optional_string(metadata, :downstream_scope) ||
          "#{boundary_intent.boundary_class}:#{target_id}",
      "extensions" => normalize_projection_value!(Map.get(metadata, :extensions, %{}))
    }
  end

  defp fetch_required_string!(metadata, field) do
    metadata
    |> fetch_optional_string(field)
    |> case do
      nil ->
        raise ArgumentError,
              "Citadel.BoundaryBridge.BoundaryProjectionAdapter requires #{field} metadata"

      value ->
        value
    end
  end

  defp fetch_optional_string(metadata, field) do
    metadata
    |> Map.get(field)
    |> case do
      nil ->
        nil

      value when is_binary(value) ->
        validate_non_empty_string!(value, field)

      value ->
        raise ArgumentError,
              "Citadel.BoundaryBridge.BoundaryProjectionAdapter metadata.#{field} must be a non-empty string, got: #{inspect(value)}"
    end
  end

  defp validate_non_empty_string!(value, field) when is_binary(value) do
    if value |> String.trim() |> byte_size() > 0 do
      value
    else
      raise ArgumentError,
            "Citadel.BoundaryBridge.BoundaryProjectionAdapter metadata.#{field} must be a non-empty string, got: #{inspect(value)}"
    end
  end

  defp fetch_optional_authority_packet(metadata) do
    case Map.get(metadata, :authority_packet) do
      nil ->
        nil

      %AuthorityDecisionV1{} = authority_packet ->
        authority_packet

      other ->
        raise ArgumentError,
              "Citadel.BoundaryBridge.BoundaryProjectionAdapter metadata.authority_packet must be a Citadel.AuthorityContract.AuthorityDecision.V1, got: #{inspect(other)}"
    end
  end

  defp normalize_optional_projection_value(nil), do: nil
  defp normalize_optional_projection_value(value), do: normalize_projection_value!(value)

  defp normalize_projection_value!(value) do
    value
    |> dump_packet_structs!()
    |> CanonicalJson.normalize!()
  end

  defp dump_packet_structs!(%DateTime{} = value), do: value
  defp dump_packet_structs!(%NaiveDateTime{} = value), do: value
  defp dump_packet_structs!(%Date{} = value), do: value
  defp dump_packet_structs!(%Time{} = value), do: value

  defp dump_packet_structs!(%module{} = value) do
    if function_exported?(module, :dump, 1) do
      value
      |> module.dump()
      |> dump_packet_structs!()
    else
      raise ArgumentError,
            "Citadel.BoundaryBridge.BoundaryProjectionAdapter cannot project unsupported struct #{inspect(module)}"
    end
  end

  defp dump_packet_structs!(value) when is_map(value) do
    Map.new(value, fn {key, nested_value} ->
      {key, dump_packet_structs!(nested_value)}
    end)
  end

  defp dump_packet_structs!(value) when is_list(value),
    do: Enum.map(value, &dump_packet_structs!/1)

  defp dump_packet_structs!(value), do: value
end
