defmodule Citadel.RuntimeObservation do
  @moduledoc """
  Host-local normalized observation produced from query or signal ingress.
  """

  alias Citadel.ContractCore.Value
  alias Jido.Integration.V2.EvidenceRef
  alias Jido.Integration.V2.GovernanceRef
  alias Jido.Integration.V2.SubjectRef

  @schema [
    observation_id: :string,
    request_id: :string,
    session_id: :string,
    signal_id: :string,
    signal_cursor: :string,
    runtime_ref_id: :string,
    event_kind: :string,
    event_at: :datetime,
    status: :string,
    output: :json_value,
    artifacts: {:list, :json_value},
    payload: {:map, :json},
    subject_ref: {:struct, SubjectRef},
    evidence_refs: {:list, {:struct, EvidenceRef}},
    governance_refs: {:list, {:struct, GovernanceRef}},
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)
  @lineage_payload_keys [
    "subject_ref",
    "evidence_refs",
    "governance_refs",
    "review_projection",
    "derived_state_attachment"
  ]

  @type t :: %__MODULE__{
          observation_id: String.t(),
          request_id: String.t() | nil,
          session_id: String.t(),
          signal_id: String.t(),
          signal_cursor: String.t() | nil,
          runtime_ref_id: String.t(),
          event_kind: String.t(),
          event_at: DateTime.t(),
          status: String.t() | nil,
          output: term(),
          artifacts: [term()],
          payload: map(),
          subject_ref: SubjectRef.t(),
          evidence_refs: [EvidenceRef.t()],
          governance_refs: [GovernanceRef.t()],
          extensions: map()
        }

  @enforce_keys [
    :observation_id,
    :session_id,
    :signal_id,
    :runtime_ref_id,
    :event_kind,
    :event_at,
    :payload,
    :subject_ref
  ]
  defstruct observation_id: nil,
            request_id: nil,
            session_id: nil,
            signal_id: nil,
            signal_cursor: nil,
            runtime_ref_id: nil,
            event_kind: nil,
            event_at: nil,
            status: nil,
            output: nil,
            artifacts: [],
            payload: %{},
            subject_ref: nil,
            evidence_refs: [],
            governance_refs: [],
            extensions: %{}

  def schema, do: @schema

  def new!(%__MODULE__{} = observation) do
    observation
    |> dump()
    |> new!()
  end

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.RuntimeObservation", @fields)

    observation = %__MODULE__{
      observation_id:
        Value.required(attrs, :observation_id, "Citadel.RuntimeObservation", fn value ->
          Value.string!(value, "Citadel.RuntimeObservation.observation_id")
        end),
      request_id:
        Value.optional(
          attrs,
          :request_id,
          "Citadel.RuntimeObservation",
          fn value ->
            Value.string!(value, "Citadel.RuntimeObservation.request_id")
          end,
          nil
        ),
      session_id:
        Value.required(attrs, :session_id, "Citadel.RuntimeObservation", fn value ->
          Value.string!(value, "Citadel.RuntimeObservation.session_id")
        end),
      signal_id:
        Value.required(attrs, :signal_id, "Citadel.RuntimeObservation", fn value ->
          Value.string!(value, "Citadel.RuntimeObservation.signal_id")
        end),
      signal_cursor:
        Value.optional(
          attrs,
          :signal_cursor,
          "Citadel.RuntimeObservation",
          fn value ->
            Value.string!(value, "Citadel.RuntimeObservation.signal_cursor")
          end,
          nil
        ),
      runtime_ref_id:
        Value.required(attrs, :runtime_ref_id, "Citadel.RuntimeObservation", fn value ->
          Value.string!(value, "Citadel.RuntimeObservation.runtime_ref_id")
        end),
      event_kind:
        Value.required(attrs, :event_kind, "Citadel.RuntimeObservation", fn value ->
          Value.string!(value, "Citadel.RuntimeObservation.event_kind")
        end),
      event_at:
        Value.required(attrs, :event_at, "Citadel.RuntimeObservation", fn value ->
          Value.datetime!(value, "Citadel.RuntimeObservation.event_at")
        end),
      status:
        Value.optional(
          attrs,
          :status,
          "Citadel.RuntimeObservation",
          fn value ->
            Value.string!(value, "Citadel.RuntimeObservation.status")
          end,
          nil
        ),
      output:
        Value.optional(
          attrs,
          :output,
          "Citadel.RuntimeObservation",
          fn value ->
            Value.json_value!(value, "Citadel.RuntimeObservation.output")
          end,
          nil
        ),
      artifacts:
        Value.optional(
          attrs,
          :artifacts,
          "Citadel.RuntimeObservation",
          fn value ->
            Value.list!(value, "Citadel.RuntimeObservation.artifacts", fn item ->
              Value.json_value!(item, "Citadel.RuntimeObservation.artifacts")
            end)
          end,
          []
        ),
      payload:
        Value.required(attrs, :payload, "Citadel.RuntimeObservation", fn value ->
          Value.json_object!(value, "Citadel.RuntimeObservation.payload")
        end),
      subject_ref:
        Value.required(attrs, :subject_ref, "Citadel.RuntimeObservation", fn value ->
          Value.module!(value, SubjectRef, "Citadel.RuntimeObservation.subject_ref")
        end),
      evidence_refs:
        Value.optional(
          attrs,
          :evidence_refs,
          "Citadel.RuntimeObservation",
          fn value ->
            Value.list!(value, "Citadel.RuntimeObservation.evidence_refs", fn item ->
              Value.module!(item, EvidenceRef, "Citadel.RuntimeObservation.evidence_refs")
            end)
          end,
          []
        ),
      governance_refs:
        Value.optional(
          attrs,
          :governance_refs,
          "Citadel.RuntimeObservation",
          fn value ->
            Value.list!(value, "Citadel.RuntimeObservation.governance_refs", fn item ->
              Value.module!(item, GovernanceRef, "Citadel.RuntimeObservation.governance_refs")
            end)
          end,
          []
        ),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.RuntimeObservation",
          fn value ->
            Value.json_object!(value, "Citadel.RuntimeObservation.extensions")
          end,
          %{}
        )
    }

    validate_payload!(observation.payload)
    observation
  end

  def dump(%__MODULE__{} = observation) do
    %{
      observation_id: observation.observation_id,
      request_id: observation.request_id,
      session_id: observation.session_id,
      signal_id: observation.signal_id,
      signal_cursor: observation.signal_cursor,
      runtime_ref_id: observation.runtime_ref_id,
      event_kind: observation.event_kind,
      event_at: observation.event_at,
      status: observation.status,
      output: observation.output,
      artifacts: observation.artifacts,
      payload: observation.payload,
      subject_ref: SubjectRef.dump(observation.subject_ref),
      evidence_refs: Enum.map(observation.evidence_refs, &EvidenceRef.dump/1),
      governance_refs: Enum.map(observation.governance_refs, &GovernanceRef.dump/1),
      extensions: observation.extensions
    }
  end

  @doc """
  Returns the stable upper-consumer field set for structured runtime reads.
  """
  def stable_read_fields do
    [
      :observation_id,
      :request_id,
      :session_id,
      :signal_id,
      :signal_cursor,
      :runtime_ref_id,
      :event_kind,
      :event_at,
      :status,
      :subject_ref,
      :evidence_refs,
      :governance_refs
    ]
  end

  @doc """
  Returns the wake reason surface used by semantic and northbound consumers.
  """
  def wake_reason(%__MODULE__{} = observation) do
    %{
      event_kind: observation.event_kind,
      status: observation.status,
      subject_kind: observation.subject_ref.kind,
      subject_id: observation.subject_ref.id
    }
  end

  @doc """
  Returns the stable structured read descriptor for one observation.
  """
  def read_descriptor(%__MODULE__{} = observation) do
    %{
      observation_id: observation.observation_id,
      request_id: observation.request_id,
      session_id: observation.session_id,
      signal_id: observation.signal_id,
      signal_cursor: observation.signal_cursor,
      runtime_ref_id: observation.runtime_ref_id,
      event_kind: observation.event_kind,
      event_at: observation.event_at,
      status: observation.status,
      subject_ref: SubjectRef.dump(observation.subject_ref),
      evidence_ref_count: length(observation.evidence_refs),
      governance_ref_count: length(observation.governance_refs)
    }
  end

  defp validate_payload!(payload) do
    offending_keys =
      payload
      |> Map.keys()
      |> Enum.filter(&(&1 in @lineage_payload_keys))

    if offending_keys != [] do
      raise ArgumentError,
            "Citadel.RuntimeObservation.payload must not duplicate explicit lineage fields: #{inspect(offending_keys)}"
    end

    payload
  end
end

defmodule Citadel.TraceEnvelope do
  @moduledoc """
  Canonical Citadel-owned trace publication value.
  """

  alias Citadel.ContractCore.{CanonicalJson, Value}
  alias Citadel.ObservabilityContract.CardinalityBounds
  alias Citadel.ObservabilityContract.Trace, as: TraceContract

  @schema [
    trace_envelope_id: :string,
    record_kind: {:enum, TraceContract.record_kinds()},
    family: :string,
    name: :string,
    phase: :string,
    trace_id: :string,
    tenant_id: :string,
    session_id: :string,
    request_id: :string,
    decision_id: :string,
    snapshot_seq: :non_neg_integer,
    signal_id: :string,
    outbox_entry_id: :string,
    boundary_ref: :string,
    span_id: :string,
    parent_span_id: :string,
    occurred_at: :datetime,
    started_at: :datetime,
    finished_at: :datetime,
    status: :string,
    attributes: {:map, :json},
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)
  @max_attribute_entries 32
  @max_extension_entries 16
  @attribute_overflow_key "citadel.trace_attribute_overflow"
  @extension_overflow_key "citadel.trace_extension_overflow"
  @priority_payload_keys [
    "canonical_idempotency_key",
    "idempotency_key",
    "release_manifest_ref",
    "evidence_owner_ref",
    "platform_envelope_id"
  ]
  @banned_payload_fragments [
    "raw_payload",
    "payload_body",
    "provider_request",
    "provider_response",
    "raw_webhook",
    "raw_nl",
    "raw_text",
    "raw_input",
    "transcript",
    "prompt",
    "credential",
    "secret",
    "password",
    "token",
    "opaque_handle",
    "process_handle",
    "pid",
    "port",
    "function"
  ]

  @type record_kind :: :event | :span

  @type t :: %__MODULE__{
          trace_envelope_id: String.t(),
          record_kind: record_kind(),
          family: String.t(),
          name: String.t(),
          phase: String.t(),
          trace_id: String.t(),
          tenant_id: String.t() | nil,
          session_id: String.t() | nil,
          request_id: String.t() | nil,
          decision_id: String.t() | nil,
          snapshot_seq: non_neg_integer() | nil,
          signal_id: String.t() | nil,
          outbox_entry_id: String.t() | nil,
          boundary_ref: String.t() | nil,
          span_id: String.t() | nil,
          parent_span_id: String.t() | nil,
          occurred_at: DateTime.t() | nil,
          started_at: DateTime.t() | nil,
          finished_at: DateTime.t() | nil,
          status: String.t() | nil,
          attributes: map(),
          extensions: map()
        }

  @enforce_keys [
    :trace_envelope_id,
    :record_kind,
    :family,
    :name,
    :phase,
    :trace_id,
    :attributes,
    :extensions
  ]
  defstruct trace_envelope_id: nil,
            record_kind: :event,
            family: nil,
            name: nil,
            phase: nil,
            trace_id: nil,
            tenant_id: nil,
            session_id: nil,
            request_id: nil,
            decision_id: nil,
            snapshot_seq: nil,
            signal_id: nil,
            outbox_entry_id: nil,
            boundary_ref: nil,
            span_id: nil,
            parent_span_id: nil,
            occurred_at: nil,
            started_at: nil,
            finished_at: nil,
            status: nil,
            attributes: %{},
            extensions: %{}

  def schema, do: @schema

  def new(%__MODULE__{} = envelope), do: {:ok, new!(envelope)}

  def new(attrs) do
    {:ok, new!(attrs)}
  rescue
    error in ArgumentError -> {:error, error}
  end

  def new!(%__MODULE__{} = envelope) do
    envelope
    |> dump()
    |> new!()
  end

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.TraceEnvelope", @fields)

    envelope = %__MODULE__{
      trace_envelope_id:
        Value.required(attrs, :trace_envelope_id, "Citadel.TraceEnvelope", fn value ->
          Value.string!(value, "Citadel.TraceEnvelope.trace_envelope_id")
        end),
      record_kind:
        Value.required(attrs, :record_kind, "Citadel.TraceEnvelope", fn value ->
          Value.enum!(value, TraceContract.record_kinds(), "Citadel.TraceEnvelope.record_kind")
        end),
      family:
        Value.required(attrs, :family, "Citadel.TraceEnvelope", fn value ->
          normalize_stringish!(value, "Citadel.TraceEnvelope.family")
        end),
      name:
        Value.required(attrs, :name, "Citadel.TraceEnvelope", fn value ->
          Value.string!(value, "Citadel.TraceEnvelope.name")
        end),
      phase:
        Value.required(attrs, :phase, "Citadel.TraceEnvelope", fn value ->
          Value.string!(value, "Citadel.TraceEnvelope.phase")
        end),
      trace_id:
        Value.required(attrs, :trace_id, "Citadel.TraceEnvelope", fn value ->
          Value.string!(value, "Citadel.TraceEnvelope.trace_id")
        end),
      tenant_id:
        Value.optional(
          attrs,
          :tenant_id,
          "Citadel.TraceEnvelope",
          fn value ->
            Value.string!(value, "Citadel.TraceEnvelope.tenant_id")
          end,
          nil
        ),
      session_id:
        Value.optional(
          attrs,
          :session_id,
          "Citadel.TraceEnvelope",
          fn value ->
            Value.string!(value, "Citadel.TraceEnvelope.session_id")
          end,
          nil
        ),
      request_id:
        Value.optional(
          attrs,
          :request_id,
          "Citadel.TraceEnvelope",
          fn value ->
            Value.string!(value, "Citadel.TraceEnvelope.request_id")
          end,
          nil
        ),
      decision_id:
        Value.optional(
          attrs,
          :decision_id,
          "Citadel.TraceEnvelope",
          fn value ->
            Value.string!(value, "Citadel.TraceEnvelope.decision_id")
          end,
          nil
        ),
      snapshot_seq:
        Value.optional(
          attrs,
          :snapshot_seq,
          "Citadel.TraceEnvelope",
          fn value ->
            Value.non_neg_integer!(value, "Citadel.TraceEnvelope.snapshot_seq")
          end,
          nil
        ),
      signal_id:
        Value.optional(
          attrs,
          :signal_id,
          "Citadel.TraceEnvelope",
          fn value ->
            Value.string!(value, "Citadel.TraceEnvelope.signal_id")
          end,
          nil
        ),
      outbox_entry_id:
        Value.optional(
          attrs,
          :outbox_entry_id,
          "Citadel.TraceEnvelope",
          fn value ->
            Value.string!(value, "Citadel.TraceEnvelope.outbox_entry_id")
          end,
          nil
        ),
      boundary_ref:
        Value.optional(
          attrs,
          :boundary_ref,
          "Citadel.TraceEnvelope",
          fn value ->
            Value.string!(value, "Citadel.TraceEnvelope.boundary_ref")
          end,
          nil
        ),
      span_id:
        Value.optional(
          attrs,
          :span_id,
          "Citadel.TraceEnvelope",
          fn value ->
            Value.string!(value, "Citadel.TraceEnvelope.span_id")
          end,
          nil
        ),
      parent_span_id:
        Value.optional(
          attrs,
          :parent_span_id,
          "Citadel.TraceEnvelope",
          fn value ->
            Value.string!(value, "Citadel.TraceEnvelope.parent_span_id")
          end,
          nil
        ),
      occurred_at:
        Value.optional(
          attrs,
          :occurred_at,
          "Citadel.TraceEnvelope",
          fn value ->
            Value.datetime!(value, "Citadel.TraceEnvelope.occurred_at")
          end,
          nil
        ),
      started_at:
        Value.optional(
          attrs,
          :started_at,
          "Citadel.TraceEnvelope",
          fn value ->
            Value.datetime!(value, "Citadel.TraceEnvelope.started_at")
          end,
          nil
        ),
      finished_at:
        Value.optional(
          attrs,
          :finished_at,
          "Citadel.TraceEnvelope",
          fn value ->
            Value.datetime!(value, "Citadel.TraceEnvelope.finished_at")
          end,
          nil
        ),
      status:
        Value.optional(
          attrs,
          :status,
          "Citadel.TraceEnvelope",
          fn value ->
            Value.string!(value, "Citadel.TraceEnvelope.status")
          end,
          nil
        ),
      attributes:
        Value.required(attrs, :attributes, "Citadel.TraceEnvelope", fn value ->
          Value.json_object!(value, "Citadel.TraceEnvelope.attributes")
        end),
      extensions:
        Value.required(attrs, :extensions, "Citadel.TraceEnvelope", fn value ->
          Value.json_object!(value, "Citadel.TraceEnvelope.extensions")
        end)
    }

    envelope
    |> validate_trace_shape!()
    |> bound_trace_payloads!()
  end

  def dump(%__MODULE__{} = envelope) do
    %{
      trace_envelope_id: envelope.trace_envelope_id,
      record_kind: envelope.record_kind,
      family: envelope.family,
      name: envelope.name,
      phase: envelope.phase,
      trace_id: envelope.trace_id,
      tenant_id: envelope.tenant_id,
      session_id: envelope.session_id,
      request_id: envelope.request_id,
      decision_id: envelope.decision_id,
      snapshot_seq: envelope.snapshot_seq,
      signal_id: envelope.signal_id,
      outbox_entry_id: envelope.outbox_entry_id,
      boundary_ref: envelope.boundary_ref,
      span_id: envelope.span_id,
      parent_span_id: envelope.parent_span_id,
      occurred_at: envelope.occurred_at,
      started_at: envelope.started_at,
      finished_at: envelope.finished_at,
      status: envelope.status,
      attributes: envelope.attributes,
      extensions: envelope.extensions
    }
  end

  def family_classification(%__MODULE__{} = envelope),
    do: TraceContract.family_classification(envelope.family)

  def protected_error_family?(%__MODULE__{} = envelope),
    do: family_classification(envelope) == :protected_error

  @spec trace_attribute_overflow_key() :: String.t()
  def trace_attribute_overflow_key, do: @attribute_overflow_key

  @spec trace_extension_overflow_key() :: String.t()
  def trace_extension_overflow_key, do: @extension_overflow_key

  @spec bound_trace_attributes!(map(), atom(), keyword()) :: map()
  def bound_trace_attributes!(attributes, surface, opts \\ []) do
    profile = CardinalityBounds.profile!(surface)
    label = Keyword.get(opts, :label, "Citadel.TraceEnvelope.attributes")
    max_entries = Keyword.get(opts, :max_entries, profile.max_attributes_per_span)
    overflow_key = Keyword.get(opts, :overflow_key, @attribute_overflow_key)

    attributes
    |> Value.json_object!(label)
    |> bound_payload_map!(label, profile, max_entries, overflow_key)
  end

  defp validate_trace_shape!(%__MODULE__{record_kind: :event} = envelope) do
    if TraceContract.required_event_family?(envelope.family) and
         envelope.name != TraceContract.canonical_event_name!(envelope.family) do
      raise ArgumentError,
            "Citadel.TraceEnvelope.name must match the canonical name for #{inspect(envelope.family)}"
    end

    if envelope.occurred_at == nil do
      raise ArgumentError, "Citadel.TraceEnvelope event records require occurred_at"
    end

    if envelope.started_at || envelope.finished_at do
      raise ArgumentError,
            "Citadel.TraceEnvelope event records must not carry started_at or finished_at"
    end

    envelope
  end

  defp validate_trace_shape!(%__MODULE__{record_kind: :span} = envelope) do
    if TraceContract.required_event_family?(envelope.family) do
      raise ArgumentError,
            "Citadel.TraceEnvelope required minimum families must publish as record_kind :event"
    end

    if envelope.started_at == nil or envelope.finished_at == nil do
      raise ArgumentError, "Citadel.TraceEnvelope span records require started_at and finished_at"
    end

    if envelope.occurred_at do
      raise ArgumentError, "Citadel.TraceEnvelope span records must not carry occurred_at"
    end

    envelope
  end

  defp bound_trace_payloads!(%__MODULE__{} = envelope) do
    %{
      envelope
      | attributes:
          bound_trace_attributes!(envelope.attributes, trace_surface(envelope),
            label: "Citadel.TraceEnvelope.attributes",
            max_entries: @max_attribute_entries,
            overflow_key: @attribute_overflow_key
          ),
        extensions:
          bound_trace_attributes!(envelope.extensions, :trace_export,
            label: "Citadel.TraceEnvelope.extensions",
            max_entries: @max_extension_entries,
            overflow_key: @extension_overflow_key
          )
    }
  end

  defp trace_surface(%__MODULE__{record_kind: :event}), do: :trace_event
  defp trace_surface(%__MODULE__{record_kind: :span}), do: :trace_span

  defp bound_payload_map!(map, label, profile, max_entries, overflow_key) do
    max_entries = positive_entry_limit!(max_entries, label)

    {kept_entries, overflow_refs} =
      map
      |> ordered_payload_entries()
      |> Enum.reduce({[], []}, fn {key, value}, {kept, overflow} ->
        case bound_payload_entry(key, value, label, profile, overflow_key) do
          {:keep, bounded_value} -> {[{key, bounded_value} | kept], overflow}
          {:spill, ref} -> {kept, [ref | overflow]}
        end
      end)

    kept_entries
    |> Enum.reverse()
    |> finalize_bound_payload(
      Enum.reverse(overflow_refs),
      label,
      profile,
      max_entries,
      overflow_key
    )
  end

  defp bound_payload_entry(key, value, label, profile, overflow_key) do
    cond do
      key == overflow_key ->
        {:spill, spillover_ref(label, key, value, :reserved_overflow_key, profile)}

      byte_size(key) > profile.max_attribute_key_bytes ->
        {:spill, spillover_ref(label, key, value, :key_bytes, profile)}

      prohibited_trace_payload_key?(key, profile) ->
        {:spill, spillover_ref(label, key, value, :raw_payload_field, profile)}

      true ->
        case bound_payload_value(value, "#{label}.#{key}", key, profile, 1) do
          {:keep, bounded_value} -> {:keep, bounded_value}
          {:spill, ref} -> {:keep, ref}
        end
    end
  end

  defp bound_payload_value(value, _label, _key, _profile, _depth)
       when is_nil(value) or is_boolean(value) or is_integer(value) or is_float(value),
       do: {:keep, value}

  defp bound_payload_value(value, label, key, profile, _depth) when is_binary(value) do
    if encoded_byte_size(value) > profile.max_attribute_value_bytes do
      {:spill, spillover_ref(label, key, value, :value_bytes, profile)}
    else
      {:keep, value}
    end
  end

  defp bound_payload_value(value, label, key, profile, depth) when is_list(value) do
    cond do
      encoded_byte_size(value) > profile.max_attribute_value_bytes ->
        {:spill, spillover_ref(label, key, value, :value_bytes, profile)}

      depth > profile.max_map_depth ->
        {:spill, spillover_ref(label, key, value, :map_depth, profile)}

      length(value) > profile.max_collection_items ->
        {:spill, spillover_ref(label, key, value, :collection_size, profile)}

      true ->
        bounded =
          value
          |> Enum.with_index()
          |> Enum.map(fn {item, index} ->
            case bound_payload_value(item, "#{label}[#{index}]", key, profile, depth + 1) do
              {:keep, bounded_item} -> bounded_item
              {:spill, ref} -> ref
            end
          end)

        {:keep, bounded}
    end
  end

  defp bound_payload_value(value, label, key, profile, depth) when is_map(value) do
    cond do
      encoded_byte_size(value) > profile.max_attribute_value_bytes ->
        {:spill, spillover_ref(label, key, value, :value_bytes, profile)}

      depth > profile.max_map_depth ->
        {:spill, spillover_ref(label, key, value, :map_depth, profile)}

      map_size(value) > profile.max_collection_items ->
        {:spill, spillover_ref(label, key, value, :collection_size, profile)}

      nested_payload_key_violation?(value, profile) ->
        {:spill, spillover_ref(label, key, value, :nested_key_bounds, profile)}

      true ->
        bounded =
          value
          |> ordered_payload_entries()
          |> Enum.map(fn {nested_key, nested_value} ->
            case bound_payload_value(
                   nested_value,
                   "#{label}.#{nested_key}",
                   nested_key,
                   profile,
                   depth + 1
                 ) do
              {:keep, bounded_value} -> {nested_key, bounded_value}
              {:spill, ref} -> {nested_key, ref}
            end
          end)
          |> Map.new()

        {:keep, bounded}
    end
  end

  defp finalize_bound_payload(
         kept_entries,
         overflow_refs,
         label,
         profile,
         max_entries,
         overflow_key
       ) do
    cond do
      overflow_refs == [] and length(kept_entries) <= max_entries ->
        Map.new(kept_entries)

      true ->
        inline_limit = max(max_entries - 1, 0)
        {inline_entries, excess_entries} = Enum.split(kept_entries, inline_limit)

        excess_refs =
          Enum.map(excess_entries, fn {key, value} ->
            spillover_ref(label, key, value, :attribute_count, profile)
          end)

        inline_entries
        |> Map.new()
        |> Map.put(
          overflow_key,
          overflow_summary_ref(label, overflow_refs ++ excess_refs, profile)
        )
    end
  end

  defp ordered_payload_entries(map) do
    Enum.sort_by(map, fn {key, _value} ->
      {if(key in @priority_payload_keys, do: 0, else: 1), key}
    end)
  end

  defp nested_payload_key_violation?(map, profile) do
    Enum.any?(map, fn {key, _value} ->
      byte_size(key) > profile.max_attribute_key_bytes or
        prohibited_trace_payload_key?(key, profile)
    end)
  end

  defp prohibited_trace_payload_key?(key, profile) do
    lower_key = String.downcase(key)
    blocked_keys = Enum.map(profile.trace_attribute_blocklist, &Atom.to_string/1)

    key in blocked_keys or Enum.any?(@banned_payload_fragments, &String.contains?(lower_key, &1))
  end

  defp spillover_ref(label, key, value, reason, profile) do
    encoded =
      CanonicalJson.encode!(%{
        "key" => key,
        "label" => label,
        "reason" => reason,
        "value" => value
      })

    digest = sha256_lower_hex(encoded)

    %{
      "artifact_ref" => "citadel://trace-spillover/#{digest}",
      "artifact_hash" => "sha256:#{digest}",
      "artifact_kind" => "trace_attribute_spillover",
      "byte_size" => encoded_byte_size(value),
      "overflow_reason" => Atom.to_string(reason),
      "spillover_policy" => profile.spillover_artifact_policy
    }
  end

  defp overflow_summary_ref(label, overflow_refs, profile) do
    reasons =
      overflow_refs
      |> Enum.map(&Map.fetch!(&1, "overflow_reason"))
      |> Enum.uniq()
      |> Enum.sort()

    summary = %{
      "label" => label,
      "overflow_reasons" => reasons,
      "spillover_count" => length(overflow_refs)
    }

    digest = summary |> CanonicalJson.encode!() |> sha256_lower_hex()

    Map.merge(summary, %{
      "artifact_ref" => "citadel://trace-spillover/#{digest}",
      "artifact_hash" => "sha256:#{digest}",
      "artifact_kind" => "trace_attribute_overflow_summary",
      "spillover_policy" => profile.spillover_artifact_policy
    })
  end

  defp encoded_byte_size(value), do: value |> CanonicalJson.encode!() |> byte_size()

  defp sha256_lower_hex(value) when is_binary(value) do
    :sha256
    |> :crypto.hash(value)
    |> Base.encode16(case: :lower)
  end

  defp positive_entry_limit!(value, _label) when is_integer(value) and value > 0, do: value

  defp positive_entry_limit!(value, label) do
    raise ArgumentError,
          "#{label} maximum entry count must be a positive integer, got: #{inspect(value)}"
  end

  defp normalize_stringish!(value, _label) when is_binary(value),
    do: Value.string!(value, "Citadel.TraceEnvelope.family")

  defp normalize_stringish!(value, _label) when is_atom(value), do: Atom.to_string(value)

  defp normalize_stringish!(value, label) do
    raise ArgumentError, "#{label} must be an atom or string, got: #{inspect(value)}"
  end
end

defmodule Citadel.MemoryRecord do
  @moduledoc """
  Host-local advisory memory item surfaced through `Citadel.Ports.Memory`.
  """

  alias Citadel.ContractCore.Value
  alias Citadel.ScopeRef

  @schema [
    memory_id: :string,
    scope_ref: {:struct, ScopeRef},
    session_id: :string,
    kind: :string,
    summary: :string,
    subject_links: {:list, :string},
    evidence_links: {:list, :string},
    expires_at: :datetime,
    confidence: :confidence,
    metadata: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          memory_id: String.t(),
          scope_ref: ScopeRef.t(),
          session_id: String.t() | nil,
          kind: String.t(),
          summary: String.t(),
          subject_links: [String.t()],
          evidence_links: [String.t()],
          expires_at: DateTime.t() | nil,
          confidence: float(),
          metadata: map()
        }

  @enforce_keys [
    :memory_id,
    :scope_ref,
    :kind,
    :summary,
    :subject_links,
    :evidence_links,
    :confidence,
    :metadata
  ]
  defstruct memory_id: nil,
            scope_ref: nil,
            session_id: nil,
            kind: nil,
            summary: nil,
            subject_links: [],
            evidence_links: [],
            expires_at: nil,
            confidence: 0.0,
            metadata: %{}

  def schema, do: @schema

  def new!(%__MODULE__{} = record) do
    record
    |> dump()
    |> new!()
  end

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.MemoryRecord", @fields)

    %__MODULE__{
      memory_id:
        Value.required(attrs, :memory_id, "Citadel.MemoryRecord", fn value ->
          Value.string!(value, "Citadel.MemoryRecord.memory_id")
        end),
      scope_ref:
        Value.required(attrs, :scope_ref, "Citadel.MemoryRecord", fn value ->
          Value.module!(value, ScopeRef, "Citadel.MemoryRecord.scope_ref")
        end),
      session_id:
        Value.optional(
          attrs,
          :session_id,
          "Citadel.MemoryRecord",
          fn value ->
            Value.string!(value, "Citadel.MemoryRecord.session_id")
          end,
          nil
        ),
      kind:
        Value.required(attrs, :kind, "Citadel.MemoryRecord", fn value ->
          Value.string!(value, "Citadel.MemoryRecord.kind")
        end),
      summary:
        Value.required(attrs, :summary, "Citadel.MemoryRecord", fn value ->
          Value.string!(value, "Citadel.MemoryRecord.summary")
        end),
      subject_links:
        Value.required(attrs, :subject_links, "Citadel.MemoryRecord", fn value ->
          Value.list!(value, "Citadel.MemoryRecord.subject_links", fn item ->
            Value.string!(item, "Citadel.MemoryRecord.subject_links")
          end)
        end),
      evidence_links:
        Value.required(attrs, :evidence_links, "Citadel.MemoryRecord", fn value ->
          Value.list!(value, "Citadel.MemoryRecord.evidence_links", fn item ->
            Value.string!(item, "Citadel.MemoryRecord.evidence_links")
          end)
        end),
      expires_at:
        Value.optional(
          attrs,
          :expires_at,
          "Citadel.MemoryRecord",
          fn value ->
            Value.datetime!(value, "Citadel.MemoryRecord.expires_at")
          end,
          nil
        ),
      confidence:
        Value.required(attrs, :confidence, "Citadel.MemoryRecord", fn value ->
          Value.confidence!(value, "Citadel.MemoryRecord.confidence")
        end),
      metadata:
        Value.required(attrs, :metadata, "Citadel.MemoryRecord", fn value ->
          Value.json_object!(value, "Citadel.MemoryRecord.metadata")
        end)
    }
  end

  def dump(%__MODULE__{} = record) do
    %{
      memory_id: record.memory_id,
      scope_ref: ScopeRef.dump(record.scope_ref),
      session_id: record.session_id,
      kind: record.kind,
      summary: record.summary,
      subject_links: record.subject_links,
      evidence_links: record.evidence_links,
      expires_at: record.expires_at,
      confidence: record.confidence,
      metadata: record.metadata
    }
  end
end

defmodule Citadel.BridgeCircuitPolicy do
  @moduledoc """
  Explicit fail-fast policy for outbound bridge calls.
  """

  alias Citadel.ContractCore.Value

  @allowed_scope_key_modes ["downstream_scope", "tenant_partition", "bridge_global"]
  @schema [
    failure_threshold: :positive_integer,
    window_ms: :positive_integer,
    cooldown_ms: :positive_integer,
    half_open_max_inflight: :positive_integer,
    scope_key_mode: :string,
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          failure_threshold: pos_integer(),
          window_ms: pos_integer(),
          cooldown_ms: pos_integer(),
          half_open_max_inflight: pos_integer(),
          scope_key_mode: String.t(),
          extensions: map()
        }

  @enforce_keys @fields
  defstruct @fields

  def schema, do: @schema
  def allowed_scope_key_modes, do: @allowed_scope_key_modes

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.BridgeCircuitPolicy", @fields)

    policy = %__MODULE__{
      failure_threshold:
        Value.required(attrs, :failure_threshold, "Citadel.BridgeCircuitPolicy", fn value ->
          Value.positive_integer!(value, "Citadel.BridgeCircuitPolicy.failure_threshold")
        end),
      window_ms:
        Value.required(attrs, :window_ms, "Citadel.BridgeCircuitPolicy", fn value ->
          Value.positive_integer!(value, "Citadel.BridgeCircuitPolicy.window_ms")
        end),
      cooldown_ms:
        Value.required(attrs, :cooldown_ms, "Citadel.BridgeCircuitPolicy", fn value ->
          Value.positive_integer!(value, "Citadel.BridgeCircuitPolicy.cooldown_ms")
        end),
      half_open_max_inflight:
        Value.required(attrs, :half_open_max_inflight, "Citadel.BridgeCircuitPolicy", fn value ->
          Value.positive_integer!(value, "Citadel.BridgeCircuitPolicy.half_open_max_inflight")
        end),
      scope_key_mode:
        Value.required(attrs, :scope_key_mode, "Citadel.BridgeCircuitPolicy", fn value ->
          Value.string!(value, "Citadel.BridgeCircuitPolicy.scope_key_mode")
        end),
      extensions:
        Value.required(attrs, :extensions, "Citadel.BridgeCircuitPolicy", fn value ->
          Value.json_object!(value, "Citadel.BridgeCircuitPolicy.extensions")
        end)
    }

    if policy.scope_key_mode in @allowed_scope_key_modes do
      policy
    else
      raise ArgumentError,
            "Citadel.BridgeCircuitPolicy.scope_key_mode must be one of #{inspect(@allowed_scope_key_modes)}"
    end
  end

  def dump(%__MODULE__{} = policy) do
    %{
      failure_threshold: policy.failure_threshold,
      window_ms: policy.window_ms,
      cooldown_ms: policy.cooldown_ms,
      half_open_max_inflight: policy.half_open_max_inflight,
      scope_key_mode: policy.scope_key_mode,
      extensions: policy.extensions
    }
  end
end
