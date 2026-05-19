defmodule Citadel.SessionOutbox do
  @moduledoc """
  Live in-memory session outbox working set with explicit one-to-one invariants.
  """

  alias Citadel.ActionOutboxEntry
  alias Citadel.ContractCore.Value

  @schema [
    entry_order: {:list, :string},
    entries_by_id: {:map, {:struct, ActionOutboxEntry}},
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          entry_order: [String.t()],
          entries_by_id: %{required(String.t()) => ActionOutboxEntry.t()},
          extensions: map()
        }

  @enforce_keys @fields
  defstruct @fields

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.SessionOutbox", @fields)

    outbox = %__MODULE__{
      entry_order:
        Value.required(attrs, :entry_order, "Citadel.SessionOutbox", fn value ->
          Value.unique_strings!(value, "Citadel.SessionOutbox.entry_order")
        end),
      entries_by_id:
        Value.required(attrs, :entries_by_id, "Citadel.SessionOutbox", fn value ->
          Value.map_of!(value, "Citadel.SessionOutbox.entries_by_id", fn key, entry_value ->
            entry =
              Value.module!(
                entry_value,
                ActionOutboxEntry,
                "Citadel.SessionOutbox.entries_by_id[#{key}]"
              )

            if entry.entry_id != key do
              raise ArgumentError,
                    "Citadel.SessionOutbox.entries_by_id key #{inspect(key)} does not match entry.entry_id #{inspect(entry.entry_id)}"
            end

            entry
          end)
        end),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.SessionOutbox",
          fn value ->
            Value.json_object!(value, "Citadel.SessionOutbox.extensions")
          end,
          %{}
        )
    }

    ensure_invariant!(outbox)
  end

  def dump(%__MODULE__{} = outbox) do
    %{
      entry_order: outbox.entry_order,
      entries_by_id:
        Map.new(outbox.entries_by_id, fn {id, entry} -> {id, ActionOutboxEntry.dump(entry)} end),
      extensions: outbox.extensions
    }
  end

  def ensure_invariant!(%__MODULE__{} = outbox) do
    order_ids = outbox.entry_order
    map_ids = outbox.entries_by_id |> Map.keys() |> Enum.sort()
    ordered_sorted = Enum.sort(order_ids)

    cond do
      ordered_sorted != map_ids ->
        raise ArgumentError,
              "Citadel.SessionOutbox invariant requires entry_order and entries_by_id to contain the same ids"

      Enum.uniq(order_ids) != order_ids ->
        raise ArgumentError,
              "Citadel.SessionOutbox.entry_order must contain each entry_id exactly once"

      true ->
        outbox
    end
  end

  def invariant?(%__MODULE__{} = outbox) do
    ensure_invariant!(outbox)
    true
  rescue
    ArgumentError -> false
  end

  def from_entries!(entries, extensions \\ %{}) do
    entries =
      Value.list!(entries, "Citadel.SessionOutbox.from_entries!", fn entry ->
        Value.module!(entry, ActionOutboxEntry, "Citadel.SessionOutbox.from_entries!")
      end)

    new!(%{
      entry_order: Enum.map(entries, & &1.entry_id),
      entries_by_id: Map.new(entries, fn entry -> {entry.entry_id, entry} end),
      extensions: extensions
    })
  end

  def put_entry!(%__MODULE__{} = outbox, entry) do
    entry = Value.module!(entry, ActionOutboxEntry, "Citadel.SessionOutbox.put_entry!")

    updated_order =
      if entry.entry_id in outbox.entry_order do
        outbox.entry_order
      else
        outbox.entry_order ++ [entry.entry_id]
      end

    new!(%{
      entry_order: updated_order,
      entries_by_id: Map.put(outbox.entries_by_id, entry.entry_id, entry),
      extensions: outbox.extensions
    })
  end

  def delete_entry!(%__MODULE__{} = outbox, entry_id) do
    entry_id = Value.string!(entry_id, "Citadel.SessionOutbox.delete_entry! entry_id")

    new!(%{
      entry_order: Enum.reject(outbox.entry_order, &(&1 == entry_id)),
      entries_by_id: Map.delete(outbox.entries_by_id, entry_id),
      extensions: outbox.extensions
    })
  end
end
