defmodule Citadel.Kernel.SignalIngress.PartitionRouter do
  @moduledoc false

  alias Citadel.RuntimeObservation
  alias Jido.Integration.V2.SubjectRef

  def route(subscriptions, %RuntimeObservation{} = observation, admission_policy) do
    with {:ok, partition} <- partition_for_observation(observation, admission_policy),
         {:ok, partition} <-
           require_ingress_lineage(subscriptions, observation, partition, admission_policy) do
      {:ok, partition}
    end
  end

  def remember_source_anchor(extensions, %{kind: kind, value: value})
      when kind in [:source_position, :revision] and is_binary(value) do
    Map.put(extensions, "lineage_source_anchor", %{
      "kind" => Atom.to_string(kind),
      "value" => value
    })
  end

  def remember_source_anchor(extensions, _source_anchor), do: extensions

  defp partition_for_observation(%RuntimeObservation{} = observation, admission_policy) do
    tenant_id = field_value(observation, "tenant_id")
    authority_scope = field_value(observation, "authority_scope")
    boundary_session_id = field_value(observation, "boundary_session_id")
    subject_ref = observation.subject_ref

    missing_fields =
      []
      |> maybe_missing(:tenant_id, tenant_id)
      |> maybe_missing(:authority_scope, authority_scope)

    cond do
      missing_fields != [] ->
        {:error, missing_partition_fields_rejection(missing_fields, admission_policy)}

      match?(%SubjectRef{}, subject_ref) ->
        subject_ref_map = SubjectRef.dump(subject_ref)
        partition_ref = {:subject, tenant_id, authority_scope, subject_ref.ref}

        {:ok,
         %{
           ref: partition_ref,
           key: %{
             tenant_id: tenant_id,
             authority_scope: authority_scope,
             subject_ref: subject_ref_map
           },
           tenant_scope_key: {tenant_id, authority_scope},
           delivery_order_scope: admission_policy.delivery_order_scope,
           dedupe_key: {partition_ref, dedupe_component(observation)}
         }}

      present_string?(boundary_session_id) ->
        partition_ref = {:boundary_session, tenant_id, authority_scope, boundary_session_id}

        {:ok,
         %{
           ref: partition_ref,
           key: %{
             tenant_id: tenant_id,
             authority_scope: authority_scope,
             boundary_session_id: boundary_session_id
           },
           tenant_scope_key: {tenant_id, authority_scope},
           delivery_order_scope: :boundary_session_fifo,
           dedupe_key: {partition_ref, dedupe_component(observation)}
         }}

      true ->
        {:error,
         missing_partition_fields_rejection(
           [:subject_ref_or_boundary_session_id],
           admission_policy
         )}
    end
  end

  defp require_ingress_lineage(
         subscriptions,
         %RuntimeObservation{} = observation,
         partition,
         admission_policy
       ) do
    case lineage_for_observation(observation) do
      {:ok, lineage} ->
        case source_anchor_regression(subscriptions, observation, lineage.source_anchor) do
          :ok ->
            {:ok, Map.put(partition, :lineage, lineage)}

          {:error, previous_anchor, current_anchor} ->
            {:error,
             source_anchor_regression_rejection(previous_anchor, current_anchor, admission_policy)}
        end

      {:error, missing_fields} ->
        {:error, missing_lineage_fields_rejection(missing_fields, admission_policy)}
    end
  end

  defp lineage_for_observation(%RuntimeObservation{} = observation) do
    trace_id = field_value(observation, "trace_id")

    causation_id =
      field_value(observation, "causation_id") || present_string(observation.request_id)

    canonical_idempotency_key =
      field_value(observation, "canonical_idempotency_key") ||
        field_value(observation, "idempotency_key")

    source_anchor = source_anchor(observation)

    missing_fields =
      []
      |> maybe_missing(:trace_id, trace_id)
      |> maybe_missing(:causation_id, causation_id)
      |> maybe_missing(:canonical_idempotency_key, canonical_idempotency_key)
      |> maybe_missing(:source_position_or_revision, Map.get(source_anchor, :value))

    if missing_fields == [] do
      {:ok,
       %{
         trace_id: trace_id,
         causation_id: causation_id,
         canonical_idempotency_key: canonical_idempotency_key,
         source_anchor: source_anchor
       }}
    else
      {:error, Enum.reverse(missing_fields)}
    end
  end

  defp source_anchor(%RuntimeObservation{} = observation) do
    source_position =
      field_value(observation, "source_position") ||
        present_string(observation.signal_cursor)

    source_revision =
      field_value(observation, "source_revision") ||
        field_value(observation, "revision")

    cond do
      present_string?(source_position) -> %{kind: :source_position, value: source_position}
      present_string?(source_revision) -> %{kind: :revision, value: source_revision}
      true -> %{kind: nil, value: nil}
    end
  end

  defp source_anchor_regression(
         subscriptions,
         %RuntimeObservation{} = observation,
         current_anchor
       ) do
    subscriptions
    |> Map.get(observation.session_id)
    |> previous_source_anchor()
    |> case do
      nil ->
        :ok

      previous_anchor ->
        if source_anchor_regressed?(previous_anchor, current_anchor) do
          {:error, previous_anchor, current_anchor}
        else
          :ok
        end
    end
  end

  defp previous_source_anchor(nil), do: nil

  defp previous_source_anchor(subscription) do
    extension_anchor =
      subscription.extensions
      |> Map.get("lineage_source_anchor")
      |> normalize_stored_source_anchor()

    extension_anchor ||
      source_position_anchor(subscription.transport_cursor) ||
      source_position_anchor(subscription.committed_signal_cursor) ||
      revision_anchor(Map.get(subscription.extensions, "source_revision")) ||
      revision_anchor(Map.get(subscription.extensions, "revision"))
  end

  defp source_position_anchor(value) do
    if present_string?(value), do: %{kind: :source_position, value: value}
  end

  defp revision_anchor(value) do
    if present_string?(value), do: %{kind: :revision, value: value}
  end

  defp normalize_stored_source_anchor(%{kind: kind, value: value}),
    do: normalize_source_anchor(kind, value)

  defp normalize_stored_source_anchor(%{"kind" => kind, "value" => value}),
    do: normalize_source_anchor(kind, value)

  defp normalize_stored_source_anchor(_anchor), do: nil

  defp normalize_source_anchor(kind, value) when kind in [:source_position, "source_position"],
    do: source_position_anchor(value)

  defp normalize_source_anchor(kind, value) when kind in [:revision, "revision"],
    do: revision_anchor(value)

  defp normalize_source_anchor(_kind, _value), do: nil

  defp source_anchor_regressed?(%{kind: kind, value: previous}, %{kind: kind, value: current}) do
    case {source_anchor_ordinal(previous), source_anchor_ordinal(current)} do
      {{:ok, previous_ordinal}, {:ok, current_ordinal}} -> current_ordinal < previous_ordinal
      _other -> false
    end
  end

  defp source_anchor_regressed?(_previous_anchor, _current_anchor), do: false

  defp source_anchor_ordinal(value) when is_integer(value), do: {:ok, value}

  defp source_anchor_ordinal(value) when is_binary(value) do
    value
    |> trailing_digits()
    |> case do
      "" -> :unknown
      digits -> parse_delimited_trailing_digits(value, digits)
    end
  end

  defp source_anchor_ordinal(_value), do: :unknown

  defp trailing_digits(value) do
    value
    |> String.to_charlist()
    |> Enum.reverse()
    |> Enum.take_while(fn byte -> byte in ?0..?9 end)
    |> Enum.reverse()
    |> List.to_string()
  end

  defp parse_delimited_trailing_digits(value, digits) do
    prefix_size = byte_size(value) - byte_size(digits)

    cond do
      prefix_size == 0 ->
        {:ok, String.to_integer(digits)}

      binary_part(value, prefix_size - 1, 1) in ["/", ":", "-"] ->
        {:ok, String.to_integer(digits)}

      true ->
        :unknown
    end
  end

  defp missing_partition_fields_rejection(missing_fields, admission_policy) do
    %{
      reason: :missing_partition_key_fields,
      missing_fields: Enum.reverse(missing_fields),
      safe_action: :reject,
      retry_after_ms: nil,
      resource_exhaustion?: false,
      delivery_order_scope: admission_policy.delivery_order_scope
    }
  end

  defp missing_lineage_fields_rejection(missing_fields, admission_policy) do
    %{
      reason: :missing_lineage_fields,
      missing_fields: missing_fields,
      safe_action: :reject,
      retry_after_ms: nil,
      resource_exhaustion?: false,
      delivery_order_scope: admission_policy.delivery_order_scope
    }
  end

  defp source_anchor_regression_rejection(previous_anchor, current_anchor, admission_policy) do
    %{
      reason: :regressed_source_position_or_revision,
      previous_source_anchor: previous_anchor,
      current_source_anchor: current_anchor,
      safe_action: :reject,
      retry_after_ms: nil,
      resource_exhaustion?: false,
      delivery_order_scope: admission_policy.delivery_order_scope
    }
  end

  defp field_value(%RuntimeObservation{} = observation, field) do
    observation.extensions
    |> Map.get(field)
    |> present_string()
    |> case do
      nil ->
        observation.payload
        |> Map.get(field)
        |> present_string()

      value ->
        value
    end
  end

  defp present_string(value) when is_binary(value) and value != "", do: value
  defp present_string(_value), do: nil

  defp present_string?(value), do: not is_nil(present_string(value))

  defp maybe_missing(missing_fields, field, value) do
    if present_string?(value), do: missing_fields, else: [field | missing_fields]
  end

  defp dedupe_component(%RuntimeObservation{} = observation) do
    field_value(observation, "canonical_idempotency_key") ||
      field_value(observation, "idempotency_key") ||
      field_value(observation, "causation_id") ||
      observation.signal_id
  end
end
