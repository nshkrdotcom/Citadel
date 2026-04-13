defmodule Citadel.DomainSurface.Adapters.CitadelAdapter.PayloadMigration do
  @moduledoc false

  alias Citadel.BoundarySessionDescriptor.V1, as: BoundarySessionDescriptorV1

  @spec migrate_accepted_payload!(map() | struct()) :: map()
  def migrate_accepted_payload!(%_{} = accepted),
    do: accepted |> Map.from_struct() |> migrate_accepted_payload!()

  def migrate_accepted_payload!(accepted) when is_map(accepted) do
    accepted = Map.new(accepted)

    case accepted_schema_version(accepted) do
      0 -> migrate_accepted_v0!(accepted)
      1 -> Map.drop(accepted, [:schema_version, "schema_version"])
    end
  end

  @spec migrate_boundary_session_descriptor!(map() | struct()) :: map()
  def migrate_boundary_session_descriptor!(%BoundarySessionDescriptorV1{} = descriptor) do
    BoundarySessionDescriptorV1.dump(descriptor)
  end

  def migrate_boundary_session_descriptor!(descriptor) when is_map(descriptor) do
    descriptor = Map.new(descriptor)

    case descriptor_contract_version(descriptor) do
      :v0 ->
        migrate_boundary_session_descriptor_v0!(descriptor)

      :v1 ->
        descriptor

      version ->
        raise ArgumentError,
              "unsupported boundary session descriptor contract_version: #{inspect(version)}"
    end
  end

  defp accepted_schema_version(accepted) do
    case fetch(accepted, :schema_version) do
      nil ->
        if legacy_accepted_shape?(accepted), do: 0, else: 1

      value ->
        normalize_version!(value, "citadel acceptance schema_version")
    end
  end

  defp legacy_accepted_shape?(accepted) do
    Enum.any?(
      [:request_identity, :root_trace_id, :lineage, :session, :continuity, :ingress, :lifecycle],
      &has_key?(accepted, &1)
    )
  end

  defp migrate_accepted_v0!(accepted) do
    lineage = fetch_map(accepted, :lineage, %{})
    session = fetch_map(accepted, :session, %{})
    continuity = fetch_map(accepted, :continuity, %{})
    ingress = fetch_map(accepted, :ingress, %{})
    lifecycle = fetch_map(accepted, :lifecycle, %{})

    %{
      request_id:
        fetch(
          accepted,
          :request_id,
          fetch(accepted, :request_identity, fetch(lineage, :idempotency_key))
        ),
      session_id: fetch(accepted, :session_id, fetch(session, :session_id, fetch(session, :id))),
      trace_id:
        fetch(accepted, :trace_id, fetch(accepted, :root_trace_id, fetch(lineage, :trace_id))),
      ingress_path: fetch(accepted, :ingress_path, fetch(ingress, :path)),
      lifecycle_event: fetch(accepted, :lifecycle_event, fetch(lifecycle, :event)),
      continuity_revision:
        fetch(
          accepted,
          :continuity_revision,
          fetch(accepted, :continuity_rev, fetch(continuity, :revision))
        ),
      metadata:
        fetch_map(accepted, :metadata, %{})
        |> maybe_put(:legacy_schema_version, 0)
        |> maybe_put(:lineage, lineage_metadata(lineage))
    }
  end

  defp descriptor_contract_version(descriptor) do
    case fetch(descriptor, :contract_version) do
      nil ->
        if legacy_boundary_descriptor_shape?(descriptor), do: :v0, else: nil

      value ->
        normalize_contract_version(value)
    end
  end

  defp legacy_boundary_descriptor_shape?(descriptor) do
    Enum.any?(
      [:boundary_id, :boundary_handle, :subject_id, :boundary_type, :boundary_mode],
      &has_key?(descriptor, &1)
    )
  end

  defp migrate_boundary_session_descriptor_v0!(descriptor) do
    %{
      contract_version: BoundarySessionDescriptorV1.contract_version(),
      boundary_session_id:
        fetch(descriptor, :boundary_session_id, fetch(descriptor, :boundary_id)),
      boundary_ref: fetch(descriptor, :boundary_ref, fetch(descriptor, :boundary_handle)),
      session_id: fetch(descriptor, :session_id, fetch(descriptor, :session_ref)),
      tenant_id: fetch(descriptor, :tenant_id, fetch(descriptor, :tenant_ref)),
      target_id: fetch(descriptor, :target_id, fetch(descriptor, :subject_id)),
      boundary_class:
        fetch(
          descriptor,
          :boundary_class,
          fetch(descriptor, :boundary_type, fetch(descriptor, :subject_kind))
        ),
      status: fetch(descriptor, :status),
      attach_mode: fetch(descriptor, :attach_mode, fetch(descriptor, :boundary_mode)),
      lease_expires_at: fetch(descriptor, :lease_expires_at),
      last_heartbeat_at: fetch(descriptor, :last_heartbeat_at),
      extensions:
        fetch_map(descriptor, :extensions, %{})
        |> maybe_put("legacy_contract_version", "v0")
    }
  end

  defp lineage_metadata(lineage) do
    %{}
    |> maybe_put(:request_name, fetch(lineage, :request_name, fetch(lineage, :command_name)))
    |> maybe_put(:route_name, fetch(lineage, :route_name))
    |> maybe_put(:subject_identity, fetch(lineage, :subject_identity, fetch(lineage, :target_id)))
    |> maybe_put(:idempotency_key, fetch(lineage, :idempotency_key))
    |> maybe_put(:trace_id, fetch(lineage, :trace_id))
  end

  defp normalize_version!(value, _label) when value in [0, 1], do: value
  defp normalize_version!("0", _label), do: 0
  defp normalize_version!("1", _label), do: 1
  defp normalize_version!("v0", _label), do: 0
  defp normalize_version!("v1", _label), do: 1

  defp normalize_version!(value, label) do
    raise ArgumentError, "#{label} must be 0 or 1, got: #{inspect(value)}"
  end

  defp normalize_contract_version("v0"), do: :v0
  defp normalize_contract_version("v1"), do: :v1
  defp normalize_contract_version(0), do: :v0
  defp normalize_contract_version(1), do: :v1
  defp normalize_contract_version("0"), do: :v0
  defp normalize_contract_version("1"), do: :v1
  defp normalize_contract_version(other), do: other

  defp fetch(map, key, default \\ nil) do
    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      Map.has_key?(map, Atom.to_string(key)) -> Map.get(map, Atom.to_string(key))
      true -> default
    end
  end

  defp fetch_map(map, key, default) do
    case fetch(map, key, default) do
      %{} = value -> Map.new(value)
      _other -> default
    end
  end

  defp has_key?(map, key) do
    Map.has_key?(map, key) or Map.has_key?(map, Atom.to_string(key))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, value) when value == %{}, do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
