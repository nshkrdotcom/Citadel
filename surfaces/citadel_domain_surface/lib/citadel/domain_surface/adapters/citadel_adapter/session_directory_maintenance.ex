defmodule Citadel.DomainSurface.Adapters.CitadelAdapter.SessionDirectoryMaintenance do
  @moduledoc false

  @behaviour Citadel.DomainSurface.Adapters.CitadelAdapter.MaintenanceSurface

  alias Citadel.ActionOutboxEntry
  alias Citadel.PersistedSessionBlob
  alias Citadel.Kernel.SessionDirectory
  alias Citadel.DomainSurface.Adapters.CitadelAdapter.RequestContext

  @type selector :: keyword() | %{optional(atom() | String.t()) => term()}
  @type replacement_entry ::
          ActionOutboxEntry.t()
          | keyword()
          | %{optional(atom() | String.t()) => term()}
          | struct()
  @type operation :: term()

  @spec inspect_dead_letter(String.t(), RequestContext.t(), keyword()) ::
          Citadel.DomainSurface.Adapters.CitadelAdapter.MaintenanceSurface.operation_result()
  @impl true
  def inspect_dead_letter(entry_id, %RequestContext{}, opts)
      when is_binary(entry_id) and entry_id != "" do
    session_directory = session_directory(opts)

    with {:ok, %{session_id: session_id, entry: entry}} <-
           SessionDirectory.resolve_outbox_entry(session_directory, entry_id) do
      {:ok,
       inspection_result(
         session_id,
         entry,
         SessionDirectory.inspect_session(session_directory, session_id)
       )}
    end
  end

  def inspect_dead_letter(_entry_id, %RequestContext{}, _opts), do: {:error, :invalid_entry_id}

  @spec clear_dead_letter(String.t(), String.t(), RequestContext.t(), keyword()) ::
          Citadel.DomainSurface.Adapters.CitadelAdapter.MaintenanceSurface.operation_result()
  @impl true
  def clear_dead_letter(entry_id, override_reason, %RequestContext{}, opts) do
    with :ok <- validate_entry_id(entry_id),
         :ok <- validate_override_reason(override_reason),
         {:ok, %PersistedSessionBlob{} = blob} <-
           SessionDirectory.clear_dead_letter(session_directory(opts), entry_id, override_reason) do
      {:ok, mutation_result(:clear_dead_letter, blob, entry_id, override_reason)}
    end
  end

  @spec retry_dead_letter(String.t(), String.t(), RequestContext.t(), keyword()) ::
          Citadel.DomainSurface.Adapters.CitadelAdapter.MaintenanceSurface.operation_result()
  @impl true
  def retry_dead_letter(entry_id, override_reason, %RequestContext{}, opts) do
    with :ok <- validate_entry_id(entry_id),
         :ok <- validate_override_reason(override_reason),
         {:ok, retry_opts} <- normalize_keyword(Keyword.get(opts, :retry_opts, [])),
         {:ok, %PersistedSessionBlob{} = blob} <-
           SessionDirectory.retry_dead_letter_with_override(
             session_directory(opts),
             entry_id,
             override_reason,
             retry_opts
           ) do
      {:ok, mutation_result(:retry_dead_letter, blob, entry_id, override_reason)}
    end
  end

  @spec replace_dead_letter(
          String.t(),
          replacement_entry(),
          String.t(),
          RequestContext.t(),
          keyword()
        ) :: Citadel.DomainSurface.Adapters.CitadelAdapter.MaintenanceSurface.operation_result()
  @impl true
  def replace_dead_letter(entry_id, replacement_entry, override_reason, %RequestContext{}, opts) do
    with :ok <- validate_entry_id(entry_id),
         :ok <- validate_override_reason(override_reason),
         {:ok, replacement_entry} <- normalize_replacement_entry(replacement_entry),
         {:ok, %PersistedSessionBlob{} = blob} <-
           SessionDirectory.replace_dead_letter(
             session_directory(opts),
             entry_id,
             replacement_entry,
             override_reason
           ) do
      {:ok, mutation_result(:replace_dead_letter, blob, entry_id, override_reason)}
    end
  end

  @spec recover_dead_letters(selector(), operation(), RequestContext.t(), keyword()) ::
          Citadel.DomainSurface.Adapters.CitadelAdapter.MaintenanceSurface.recovery_result()
  @impl true
  def recover_dead_letters(selector, operation, %RequestContext{}, opts) do
    with {:ok, selector} <- normalize_selector(selector),
         {:ok, affected_count} <-
           SessionDirectory.bulk_recover_dead_letters(
             session_directory(opts),
             selector,
             operation
           ) do
      {:ok,
       %{
         selector: selector,
         recovery_operation: operation,
         affected_count: affected_count
       }}
    end
  end

  defp session_directory(opts), do: Keyword.get(opts, :session_directory, SessionDirectory)

  defp inspection_result(session_id, entry, session_inspection) do
    %{
      entry_id: entry.entry_id,
      session_id: session_id,
      entry: entry_summary(entry),
      session: session_summary(session_id, session_inspection)
    }
  end

  defp mutation_result(operation, %PersistedSessionBlob{} = blob, entry_id, override_reason) do
    %{
      entry_id: entry_id,
      override_reason: override_reason,
      session: blob_summary(blob),
      mutation: operation
    }
  end

  defp entry_summary(%ActionOutboxEntry{} = entry) do
    %{
      entry_id: entry.entry_id,
      action_kind: entry.action.action_kind,
      replay_status: entry.replay_status,
      ordering_mode: entry.ordering_mode,
      attempt_count: entry.attempt_count,
      max_attempts: entry.max_attempts,
      next_attempt_at: iso8601(entry.next_attempt_at),
      inserted_at: iso8601(entry.inserted_at),
      last_error_code: entry.last_error_code,
      dead_letter_reason: entry.dead_letter_reason
    }
  end

  defp session_summary(session_id, session_inspection) when is_map(session_inspection) do
    raw_blob = Map.get(session_inspection, :raw_blob, Map.get(session_inspection, "raw_blob"))
    envelope = envelope_from_blob(raw_blob)

    %{
      session_id: session_id,
      continuity_revision:
        Map.get(envelope, :continuity_revision, Map.get(envelope, "continuity_revision")),
      lifecycle_status:
        Map.get(envelope, :lifecycle_status, Map.get(envelope, "lifecycle_status")),
      boundary_ref: Map.get(envelope, :boundary_ref, Map.get(envelope, "boundary_ref")),
      blocked_failure:
        Map.get(
          Map.get(envelope, :extensions, Map.get(envelope, "extensions", %{})),
          "blocked_failure"
        ),
      blocked_entries:
        session_inspection
        |> Map.get(:blocked_entries, Map.get(session_inspection, "blocked_entries", %{}))
        |> normalize_blocked_entries(),
      quarantine:
        session_inspection
        |> Map.get(:quarantine, Map.get(session_inspection, "quarantine"))
        |> normalize_quarantine(),
      dead_letter_count: count_dead_letters(raw_blob)
    }
  end

  defp blob_summary(%PersistedSessionBlob{} = blob) do
    %{
      session_id: blob.session_id,
      continuity_revision: blob.envelope.continuity_revision,
      lifecycle_status: blob.envelope.lifecycle_status,
      boundary_ref: blob.envelope.boundary_ref,
      blocked_failure: Map.get(blob.envelope.extensions, "blocked_failure"),
      dead_letter_count: count_dead_letters(blob)
    }
  end

  defp envelope_from_blob(%PersistedSessionBlob{envelope: envelope}), do: envelope
  defp envelope_from_blob(%{envelope: envelope}), do: envelope
  defp envelope_from_blob(_raw_blob), do: %{}

  defp normalize_blocked_entries(blocked_entries) when is_map(blocked_entries) do
    blocked_entries
    |> Map.values()
    |> Enum.sort_by(&Map.get(&1, :entry_id, Map.get(&1, "entry_id", "")))
  end

  defp normalize_blocked_entries(_blocked_entries), do: []

  defp normalize_quarantine(nil), do: nil

  defp normalize_quarantine(%{reason_family: reason_family, eviction_deadline: eviction_deadline}) do
    %{reason_family: reason_family, eviction_deadline: iso8601(eviction_deadline)}
  end

  defp normalize_quarantine(%{
         "reason_family" => reason_family,
         "eviction_deadline" => eviction_deadline
       }) do
    %{reason_family: reason_family, eviction_deadline: iso8601(eviction_deadline)}
  end

  defp normalize_quarantine(other), do: other

  defp count_dead_letters(%PersistedSessionBlob{outbox_entries: outbox_entries}) do
    outbox_entries
    |> Map.values()
    |> Enum.count(&(&1.replay_status == :dead_letter))
  end

  defp count_dead_letters(%{outbox_entries: outbox_entries}) when is_map(outbox_entries) do
    outbox_entries
    |> Map.values()
    |> Enum.count(fn entry ->
      Map.get(entry, :replay_status, Map.get(entry, "replay_status")) == :dead_letter
    end)
  end

  defp count_dead_letters(_raw_blob), do: 0

  defp iso8601(nil), do: nil
  defp iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  defp iso8601(value), do: value

  defp normalize_selector(selector) when is_map(selector), do: {:ok, selector}

  defp normalize_selector(selector) when is_list(selector) do
    if Keyword.keyword?(selector) do
      {:ok, selector}
    else
      {:error, :invalid_selector}
    end
  end

  defp normalize_selector(_selector), do: {:error, :invalid_selector}

  defp normalize_keyword(value) when value == [], do: {:ok, []}

  defp normalize_keyword(value) when is_list(value) do
    if Keyword.keyword?(value) do
      {:ok, value}
    else
      {:error, :invalid_retry_opts}
    end
  end

  defp normalize_keyword(_value), do: {:error, :invalid_retry_opts}

  defp normalize_replacement_entry(%ActionOutboxEntry{} = entry), do: {:ok, entry}

  defp normalize_replacement_entry(entry) when is_list(entry) or is_map(entry) do
    {:ok, ActionOutboxEntry.new!(entry)}
  rescue
    error in ArgumentError -> {:error, {:invalid_replacement_entry, error.message}}
  end

  defp normalize_replacement_entry(_entry), do: {:error, :invalid_replacement_entry}

  defp validate_entry_id(entry_id) when is_binary(entry_id) and entry_id != "", do: :ok
  defp validate_entry_id(_entry_id), do: {:error, :invalid_entry_id}

  defp validate_override_reason(reason) when is_binary(reason) and reason != "", do: :ok
  defp validate_override_reason(_reason), do: {:error, :invalid_override_reason}
end
