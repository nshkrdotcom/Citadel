defmodule Citadel.PersistedSessionBlob do
  @moduledoc """
  Single durable continuity write unit keyed by session id.
  """

  alias Citadel.ActionOutboxEntry
  alias Citadel.ContractCore.Value
  alias Citadel.PersistedSessionEnvelope
  alias Citadel.SessionOutbox

  @schema_version 1
  @fields [:schema_version, :session_id, :envelope, :outbox_entries, :extensions]

  @type t :: %__MODULE__{
          schema_version: pos_integer(),
          session_id: String.t(),
          envelope: PersistedSessionEnvelope.t(),
          outbox_entries: %{required(String.t()) => ActionOutboxEntry.t()},
          extensions: map()
        }

  @enforce_keys @fields
  defstruct @fields

  def schema_version, do: @schema_version

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.PersistedSessionBlob", @fields)

    blob = %__MODULE__{
      schema_version:
        Value.required(attrs, :schema_version, "Citadel.PersistedSessionBlob", fn value ->
          if value == @schema_version do
            value
          else
            raise ArgumentError,
                  "Citadel.PersistedSessionBlob.schema_version must be #{@schema_version}, got: #{inspect(value)}"
          end
        end),
      session_id:
        Value.required(attrs, :session_id, "Citadel.PersistedSessionBlob", fn value ->
          Value.string!(value, "Citadel.PersistedSessionBlob.session_id")
        end),
      envelope:
        Value.required(attrs, :envelope, "Citadel.PersistedSessionBlob", fn value ->
          Value.module!(value, PersistedSessionEnvelope, "Citadel.PersistedSessionBlob.envelope")
        end),
      outbox_entries:
        Value.required(attrs, :outbox_entries, "Citadel.PersistedSessionBlob", fn value ->
          Value.map_of!(value, "Citadel.PersistedSessionBlob.outbox_entries", fn key,
                                                                                 entry_value ->
            entry =
              Value.module!(
                entry_value,
                ActionOutboxEntry,
                "Citadel.PersistedSessionBlob.outbox_entries[#{key}]"
              )

            if entry.entry_id != key do
              raise ArgumentError,
                    "Citadel.PersistedSessionBlob.outbox_entries key #{inspect(key)} does not match entry.entry_id #{inspect(entry.entry_id)}"
            end

            entry
          end)
        end),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.PersistedSessionBlob",
          fn value ->
            Value.json_object!(value, "Citadel.PersistedSessionBlob.extensions")
          end,
          %{}
        )
    }

    validate_blob_invariants!(blob)
  end

  def dump(%__MODULE__{} = blob) do
    %{
      schema_version: blob.schema_version,
      session_id: blob.session_id,
      envelope: PersistedSessionEnvelope.dump(blob.envelope),
      outbox_entries:
        Map.new(blob.outbox_entries, fn {id, entry} -> {id, ActionOutboxEntry.dump(entry)} end),
      extensions: blob.extensions
    }
  end

  def restore_session_outbox!(%__MODULE__{} = blob) do
    ordered_entries =
      Enum.map(blob.envelope.outbox_entry_ids, fn entry_id ->
        case Map.fetch(blob.outbox_entries, entry_id) do
          {:ok, entry} ->
            entry

          :error ->
            raise ArgumentError,
                  "missing outbox entry #{inspect(entry_id)} in persisted session blob"
        end
      end)

    SessionOutbox.from_entries!(ordered_entries)
  end

  defp validate_blob_invariants!(%__MODULE__{} = blob) do
    if blob.envelope.session_id != blob.session_id do
      raise ArgumentError,
            "Citadel.PersistedSessionBlob.envelope.session_id must match blob.session_id"
    end

    ordered_sorted = Enum.sort(blob.envelope.outbox_entry_ids)
    map_ids = blob.outbox_entries |> Map.keys() |> Enum.sort()

    if ordered_sorted != map_ids do
      raise ArgumentError,
            "Citadel.PersistedSessionBlob requires envelope.outbox_entry_ids to match outbox_entries"
    end

    restore_session_outbox!(blob)
    blob
  end
end
