defmodule Citadel.BoundaryBridge.BoundaryProjectionAdapter do
  @moduledoc """
  Isolates the boundary-intent projection shape at the bridge edge.
  """

  alias Citadel.BoundaryIntent
  alias Citadel.ContractCore.CanonicalJson

  @spec project!(BoundaryIntent.t(), map()) :: map()
  def project!(%BoundaryIntent{} = boundary_intent, metadata) when is_map(metadata) do
    %{
      "boundary_intent" => normalize_projection_value!(BoundaryIntent.dump(boundary_intent)),
      "authority_packet" =>
        normalize_optional_projection_value(
          metadata["authority_packet"] || metadata[:authority_packet]
        ),
      "session_id" => metadata["session_id"] || metadata[:session_id],
      "tenant_id" => metadata["tenant_id"] || metadata[:tenant_id],
      "target_id" => metadata["target_id"] || metadata[:target_id],
      "downstream_scope" =>
        metadata["downstream_scope"] || metadata[:downstream_scope] ||
          "#{boundary_intent.boundary_class}:#{metadata["target_id"] || metadata[:target_id] || "unspecified"}",
      "extensions" =>
        normalize_projection_value!(
          Map.get(metadata, "extensions", Map.get(metadata, :extensions, %{}))
        )
    }
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
