defmodule Citadel.Runtime.SessionMigration do
  @moduledoc """
  Explicit bounded migration for persisted session continuity blobs.
  """

  alias Citadel.ActionOutboxEntry
  alias Citadel.PersistedSessionBlob
  alias Citadel.PersistedSessionEnvelope

  def migrate_blob!(%PersistedSessionBlob{} = blob), do: blob

  def migrate_blob!(%{schema_version: 1} = blob) do
    PersistedSessionBlob.new!(%{
      schema_version: 1,
      session_id: fetch(blob, :session_id),
      envelope: migrate_envelope!(fetch(blob, :envelope)),
      outbox_entries: migrate_outbox_entries!(fetch(blob, :outbox_entries)),
      extensions: fetch(blob, :extensions, %{})
    })
  end

  def migrate_blob!(%{schema_version: 0} = blob) do
    migrate_blob!(%{
      schema_version: 1,
      session_id: fetch(blob, :session_id),
      envelope:
        fetch(blob, :envelope, %{})
        |> Map.new()
        |> Map.put_new(:schema_version, 1)
        |> Map.put_new(:session_id, fetch(blob, :session_id))
        |> Map.put_new(:continuity_revision, fetch(blob, :continuity_revision, 0))
        |> Map.put_new(:owner_incarnation, fetch(blob, :owner_incarnation, 1))
        |> Map.put_new(:recent_signal_hashes, fetch(blob, :recent_signal_hashes, []))
        |> Map.put_new(:lifecycle_status, fetch(blob, :lifecycle_status, :active))
        |> Map.put_new(:outbox_entry_ids, normalize_outbox_entry_ids(blob))
        |> Map.put_new(:external_refs, fetch(blob, :external_refs, %{}))
        |> Map.put_new(:extensions, fetch(blob, :extensions, %{})),
      outbox_entries: fetch(blob, :outbox_entries, %{}),
      extensions: fetch(blob, :extensions, %{})
    })
  end

  def migrate_blob!(other) do
    raise ArgumentError, "unsupported persisted session blob schema: #{inspect(other)}"
  end

  defp migrate_envelope!(%PersistedSessionEnvelope{} = envelope), do: envelope

  defp migrate_envelope!(%{schema_version: 1} = envelope) do
    PersistedSessionEnvelope.new!(%{
      schema_version: 1,
      session_id: fetch(envelope, :session_id),
      continuity_revision: fetch(envelope, :continuity_revision),
      owner_incarnation: fetch(envelope, :owner_incarnation),
      project_binding: fetch(envelope, :project_binding),
      scope_ref: fetch(envelope, :scope_ref),
      signal_cursor: fetch(envelope, :signal_cursor),
      recent_signal_hashes: fetch(envelope, :recent_signal_hashes, []),
      lifecycle_status: fetch(envelope, :lifecycle_status, :active),
      last_active_at: fetch(envelope, :last_active_at),
      active_plan: fetch(envelope, :active_plan),
      active_authority_decision: fetch(envelope, :active_authority_decision),
      last_rejection: fetch(envelope, :last_rejection),
      boundary_ref: fetch(envelope, :boundary_ref),
      outbox_entry_ids: fetch(envelope, :outbox_entry_ids, []),
      external_refs: fetch(envelope, :external_refs, %{}),
      extensions: fetch(envelope, :extensions, %{})
    })
  end

  defp migrate_envelope!(%{schema_version: 0} = envelope) do
    migrate_envelope!(%{
      schema_version: 1,
      session_id: fetch(envelope, :session_id),
      continuity_revision: fetch(envelope, :continuity_revision, 0),
      owner_incarnation: fetch(envelope, :owner_incarnation, 1),
      project_binding: fetch(envelope, :project_binding),
      scope_ref: fetch(envelope, :scope_ref),
      signal_cursor: fetch(envelope, :signal_cursor),
      recent_signal_hashes: fetch(envelope, :recent_signal_hashes, []),
      lifecycle_status: fetch(envelope, :lifecycle_status, :active),
      last_active_at: fetch(envelope, :last_active_at),
      active_plan: fetch(envelope, :active_plan),
      active_authority_decision: fetch(envelope, :active_authority_decision),
      last_rejection: fetch(envelope, :last_rejection),
      boundary_ref: fetch(envelope, :boundary_ref),
      outbox_entry_ids: fetch(envelope, :outbox_entry_ids, []),
      external_refs: fetch(envelope, :external_refs, %{}),
      extensions: fetch(envelope, :extensions, %{})
    })
  end

  defp migrate_envelope!(other) do
    raise ArgumentError, "unsupported persisted session envelope schema: #{inspect(other)}"
  end

  defp migrate_outbox_entries!(entries) when is_map(entries) do
    Map.new(entries, fn {entry_id, entry} ->
      migrated =
        case entry do
          %ActionOutboxEntry{} = action_outbox_entry ->
            action_outbox_entry

          %{schema_version: 1} = action_outbox_entry ->
            ActionOutboxEntry.new!(action_outbox_entry)

          %{schema_version: 0} = action_outbox_entry ->
            ActionOutboxEntry.new!(%{
              schema_version: 1,
              entry_id: fetch(action_outbox_entry, :entry_id, entry_id),
              causal_group_id: fetch(action_outbox_entry, :causal_group_id, "legacy/#{entry_id}"),
              action: fetch(action_outbox_entry, :action),
              inserted_at: fetch(action_outbox_entry, :inserted_at),
              replay_status: fetch(action_outbox_entry, :replay_status, :pending),
              durable_receipt_ref: fetch(action_outbox_entry, :durable_receipt_ref),
              attempt_count: fetch(action_outbox_entry, :attempt_count, 0),
              max_attempts: fetch(action_outbox_entry, :max_attempts, 1),
              backoff_policy: fetch(action_outbox_entry, :backoff_policy),
              next_attempt_at: fetch(action_outbox_entry, :next_attempt_at),
              last_error_code: fetch(action_outbox_entry, :last_error_code),
              dead_letter_reason: fetch(action_outbox_entry, :dead_letter_reason),
              ordering_mode: fetch(action_outbox_entry, :ordering_mode, :strict),
              staleness_mode: fetch(action_outbox_entry, :staleness_mode, :requires_check),
              staleness_requirements: fetch(action_outbox_entry, :staleness_requirements),
              extensions: fetch(action_outbox_entry, :extensions, %{})
            })

          other ->
            raise ArgumentError, "unsupported action outbox entry schema: #{inspect(other)}"
        end

      {entry_id, migrated}
    end)
  end

  defp migrate_outbox_entries!(entries) when is_list(entries) do
    entries
    |> Enum.map(fn entry ->
      migrated =
        case entry do
          %ActionOutboxEntry{} = action_outbox_entry ->
            action_outbox_entry

          map when is_map(map) ->
            migrate_outbox_entries!(%{fetch(map, :entry_id) => map})
            |> Map.fetch!(fetch(map, :entry_id))
        end

      {migrated.entry_id, migrated}
    end)
    |> Map.new()
  end

  defp normalize_outbox_entry_ids(blob) do
    case fetch(blob, :outbox_entry_ids) do
      nil ->
        case fetch(blob, :outbox_entries, %{}) do
          entries when is_map(entries) -> Map.keys(entries)
          entries when is_list(entries) -> Enum.map(entries, &fetch(&1, :entry_id))
        end

      ids ->
        ids
    end
  end

  defp fetch(map, key, default \\ nil) do
    cond do
      is_map_key(map, key) -> Map.get(map, key)
      is_map_key(map, Atom.to_string(key)) -> Map.get(map, Atom.to_string(key))
      true -> default
    end
  end
end
