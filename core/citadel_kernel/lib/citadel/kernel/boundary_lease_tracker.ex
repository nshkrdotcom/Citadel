defmodule Citadel.Kernel.BoundaryLeaseTracker do
  @moduledoc """
  Host-local boundary liveness and targeted resume-classification owner.
  """

  use GenServer

  alias Citadel.BoundaryLeaseView
  alias Citadel.BoundaryResumePolicy
  alias Citadel.KernelEpochUpdate
  alias Citadel.ObservabilityContract.Telemetry
  alias Citadel.Kernel.KernelSnapshot
  alias Citadel.Kernel.SystemClock

  @flush_message :flush_boundary_epoch
  @eviction_sweep_message :eviction_sweep
  @default_eviction_policy %{
    sweep_interval_ms: 60_000,
    max_evictions_per_sweep: 128,
    lease_ttl_ms: 10 * 60_000,
    inflight_bootstrap_ttl_ms: 60_000,
    circuit_open_ttl_ms: 60_000,
    max_leases_total: 100_000,
    max_inflight_bootstraps_total: 10_000,
    max_circuit_open_keys_total: 10_000
  }

  @type bootstrap_result ::
          {:ok, BoundaryLeaseView.t()}
          | {:error, :not_ready | :resume_pending | :missing | :expired | :circuit_open | atom()}

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def record_boundary_view(server \\ __MODULE__, %BoundaryLeaseView{} = boundary_lease_view) do
    GenServer.call(server, {:record_boundary_view, boundary_lease_view})
  end

  def current_view(server \\ __MODULE__, boundary_ref) do
    GenServer.call(server, {:current_view, boundary_ref})
  end

  def classify_for_resume(server \\ __MODULE__, boundary_ref) do
    GenServer.call(server, {:classify_for_resume, boundary_ref}, :infinity)
  end

  def boundary_epoch(server \\ __MODULE__) do
    GenServer.call(server, :boundary_epoch)
  end

  def warm?(server \\ __MODULE__) do
    GenServer.call(server, :warm?)
  end

  def set_warm(server \\ __MODULE__, warm?) do
    GenServer.call(server, {:set_warm, warm?})
  end

  def set_circuit_open(server \\ __MODULE__, key, open?) do
    GenServer.call(server, {:set_circuit_open, key, open?})
  end

  def sweep_expired(server \\ __MODULE__) do
    GenServer.call(server, :sweep_expired)
  end

  def snapshot(server \\ __MODULE__) do
    GenServer.call(server, :snapshot)
  end

  @impl true
  def init(opts) do
    {:ok,
     %{
       kernel_snapshot: Keyword.get(opts, :kernel_snapshot, KernelSnapshot),
       clock: Keyword.get(opts, :clock, SystemClock),
       flush_interval_ms: Keyword.get(opts, :flush_interval_ms, 10),
       eviction_policy: normalize_eviction_policy(Keyword.get(opts, :eviction_policy, [])),
       boundary_epoch: Keyword.get(opts, :boundary_epoch, 0),
       pending_epoch: nil,
       pending_updated_at: nil,
       flush_timer_ref: nil,
       leases: %{},
       lease_last_seen_at: %{},
       warm?: Keyword.get(opts, :warm?, false),
       resume_policy: Keyword.get(opts, :resume_policy, BoundaryResumePolicy.new!(%{})),
       bootstrap_fun:
         Keyword.get(opts, :bootstrap_fun, fn _boundary_ref -> {:error, :not_ready} end),
       classification_key_fun:
         Keyword.get(opts, :classification_key_fun, fn _boundary_ref -> nil end),
       inflight: %{},
       circuit_open_keys: MapSet.new(),
       circuit_opened_at: %{},
       sweep_timer_ref: nil
     }
     |> schedule_eviction_sweep()}
  end

  @impl true
  def handle_call(
        {:record_boundary_view, %BoundaryLeaseView{} = boundary_lease_view},
        _from,
        state
      ) do
    case prepare_lease_capacity(state, boundary_lease_view.boundary_ref) do
      {:ok, state} ->
        state = update_lease(state, boundary_lease_view)
        {:reply, {:ok, state.boundary_epoch}, state}

      {:error, rejection, state} ->
        {:reply, {:error, rejection}, state}
    end
  end

  def handle_call({:current_view, boundary_ref}, _from, state) do
    {:reply, Map.get(state.leases, boundary_ref), state}
  end

  def handle_call({:classify_for_resume, boundary_ref}, from, state) do
    case Map.get(state.leases, boundary_ref) do
      %BoundaryLeaseView{} = boundary_lease_view ->
        {:reply, {:ok, boundary_lease_view}, state}

      nil ->
        coalesce_key = coalesce_key(state, boundary_ref)

        cond do
          circuit_open?(state, coalesce_key) ->
            emit_circuit_open_telemetry(boundary_ref)
            {:reply, {:error, :circuit_open}, state}

          Map.has_key?(state.inflight, coalesce_key) ->
            inflight_entry = Map.fetch!(state.inflight, coalesce_key)

            inflight =
              Map.put(state.inflight, coalesce_key, %{
                inflight_entry
                | waiters: [from | inflight_entry.waiters],
                  coalesced_request_count: inflight_entry.coalesced_request_count + 1
              })

            emit_bootstrap_backlog_telemetry(inflight)
            {:noreply, %{state | inflight: inflight}}

          true ->
            case prepare_inflight_capacity(state, coalesce_key) do
              {:ok, state} ->
                state = start_bootstrap_attempt(state, coalesce_key, boundary_ref, from)
                {:noreply, state}

              {:error, _rejection, state} ->
                {:reply, {:error, :bootstrap_capacity_exhausted}, state}
            end
        end
    end
  end

  def handle_call(:boundary_epoch, _from, state) do
    {:reply, state.boundary_epoch, state}
  end

  def handle_call(:warm?, _from, state) do
    {:reply, state.warm?, state}
  end

  def handle_call({:set_warm, warm?}, _from, state) do
    {:reply, :ok, %{state | warm?: warm?}}
  end

  def handle_call({:set_circuit_open, key, true}, _from, state) do
    case prepare_circuit_capacity(state, key) do
      {:ok, state} ->
        {:reply, :ok,
         %{
           state
           | circuit_open_keys: MapSet.put(state.circuit_open_keys, key),
             circuit_opened_at: Map.put(state.circuit_opened_at, key, state.clock.utc_now())
         }}

      {:error, rejection, state} ->
        {:reply, {:error, rejection}, state}
    end
  end

  def handle_call({:set_circuit_open, key, false}, _from, state) do
    {:reply, :ok,
     %{
       state
       | circuit_open_keys: MapSet.delete(state.circuit_open_keys, key),
         circuit_opened_at: Map.delete(state.circuit_opened_at, key)
     }}
  end

  def handle_call(:sweep_expired, _from, state) do
    {state, summary} = sweep_expired_state(state)
    {:reply, summary, state}
  end

  def handle_call(:snapshot, _from, state) do
    {:reply,
     %{
       leases: state.leases,
       lease_last_seen_at: state.lease_last_seen_at,
       inflight: state.inflight,
       circuit_open_keys: state.circuit_open_keys,
       circuit_opened_at: state.circuit_opened_at,
       eviction_policy: state.eviction_policy
     }, state}
  end

  @impl true
  def handle_info(@flush_message, %{pending_epoch: nil} = state) do
    {:noreply, %{state | flush_timer_ref: nil}}
  end

  def handle_info(@flush_message, state) do
    KernelSnapshot.publish_epoch_update(
      state.kernel_snapshot,
      KernelEpochUpdate.new!(%{
        source_owner: Atom.to_string(__MODULE__),
        constituent: :boundary_epoch,
        epoch: state.pending_epoch,
        updated_at: state.pending_updated_at,
        extensions: %{}
      })
    )

    {:noreply,
     %{
       state
       | pending_epoch: nil,
         pending_updated_at: nil,
         flush_timer_ref: nil
     }}
  end

  def handle_info({:bootstrap_result, coalesce_key, boundary_ref, result}, state) do
    case Map.get(state.inflight, coalesce_key) do
      nil ->
        {:noreply, state}

      inflight_entry ->
        cancel_timer_if_any(inflight_entry.ttl_timer_ref)

        case result do
          {:ok, %BoundaryLeaseView{} = boundary_lease_view} ->
            Enum.each(inflight_entry.waiters, &GenServer.reply(&1, {:ok, boundary_lease_view}))

            state =
              state
              |> update_lease(boundary_lease_view)
              |> clear_inflight(coalesce_key)

            emit_bootstrap_backlog_telemetry(state.inflight)
            {:noreply, state}

          {:error, reason} when reason in [:not_ready, :resume_pending] ->
            maybe_retry_bootstrap(state, coalesce_key, inflight_entry, boundary_ref)

          {:error, :circuit_open} ->
            Enum.each(inflight_entry.waiters, &GenServer.reply(&1, {:error, :circuit_open}))
            emit_circuit_open_telemetry(boundary_ref)
            state = clear_inflight(state, coalesce_key)
            {:noreply, state}

          {:error, reason} ->
            Enum.each(inflight_entry.waiters, &GenServer.reply(&1, {:error, reason}))
            state = clear_inflight(state, coalesce_key)
            {:noreply, state}
        end
    end
  end

  def handle_info({:retry_bootstrap, coalesce_key}, state) do
    case Map.get(state.inflight, coalesce_key) do
      nil ->
        {:noreply, state}

      inflight_entry ->
        if circuit_open?(state, coalesce_key) do
          Enum.each(inflight_entry.waiters, &GenServer.reply(&1, {:error, :circuit_open}))
          emit_circuit_open_telemetry(inflight_entry.boundary_ref)
          state = clear_inflight(state, coalesce_key)
          {:noreply, state}
        else
          state =
            launch_bootstrap_task(
              state,
              coalesce_key,
              inflight_entry.boundary_ref,
              inflight_entry
            )

          {:noreply, state}
        end
    end
  end

  def handle_info({:bootstrap_ttl_expired, coalesce_key}, state) do
    case Map.get(state.inflight, coalesce_key) do
      nil ->
        {:noreply, state}

      inflight_entry ->
        Enum.each(inflight_entry.waiters, &GenServer.reply(&1, {:error, :bootstrap_timeout}))
        state = clear_inflight(state, coalesce_key)
        emit_bootstrap_backlog_telemetry(state.inflight)
        {:noreply, state}
    end
  end

  def handle_info(@eviction_sweep_message, state) do
    {state, _summary} = sweep_expired_state(state)
    {:noreply, schedule_eviction_sweep(%{state | sweep_timer_ref: nil})}
  end

  defp start_bootstrap_attempt(state, coalesce_key, boundary_ref, from) do
    inflight_entry = %{
      boundary_ref: boundary_ref,
      first_requested_at: state.clock.utc_now(),
      waiters: [from],
      coalesced_request_count: 0,
      ttl_timer_ref: nil,
      retry_timer_ref: nil
    }

    state = put_inflight(state, coalesce_key, inflight_entry)

    state =
      launch_bootstrap_task(
        state,
        coalesce_key,
        boundary_ref,
        Map.fetch!(state.inflight, coalesce_key)
      )

    emit_bootstrap_backlog_telemetry(state.inflight)
    state
  end

  defp launch_bootstrap_task(state, coalesce_key, boundary_ref, inflight_entry) do
    owner = self()

    ttl_timer_ref =
      Process.send_after(
        self(),
        {:bootstrap_ttl_expired, coalesce_key},
        state.resume_policy.coalesced_request_ttl_ms
      )

    Task.start(fn ->
      send(
        owner,
        {:bootstrap_result, coalesce_key, boundary_ref, state.bootstrap_fun.(boundary_ref)}
      )
    end)

    put_inflight(state, coalesce_key, %{
      inflight_entry
      | ttl_timer_ref: ttl_timer_ref,
        retry_timer_ref: nil
    })
  end

  defp maybe_retry_bootstrap(state, coalesce_key, inflight_entry, boundary_ref) do
    waited_ms =
      DateTime.diff(state.clock.utc_now(), inflight_entry.first_requested_at, :millisecond)

    if waited_ms + state.resume_policy.retry_interval_ms > state.resume_policy.max_wait_ms do
      Enum.each(inflight_entry.waiters, &GenServer.reply(&1, {:error, :resume_wait_exhausted}))
      state = clear_inflight(state, coalesce_key)
      {:noreply, state}
    else
      retry_timer_ref =
        Process.send_after(
          self(),
          {:retry_bootstrap, coalesce_key},
          state.resume_policy.retry_interval_ms
        )

      updated_inflight_entry = %{
        inflight_entry
        | boundary_ref: boundary_ref,
          retry_timer_ref: retry_timer_ref,
          ttl_timer_ref: nil
      }

      state = put_inflight(state, coalesce_key, updated_inflight_entry)
      emit_bootstrap_backlog_telemetry(state.inflight)
      {:noreply, state}
    end
  end

  defp update_lease(state, %BoundaryLeaseView{} = boundary_lease_view) do
    previous = Map.get(state.leases, boundary_lease_view.boundary_ref)

    if decision_relevant_boundary_view(previous) ==
         decision_relevant_boundary_view(boundary_lease_view) do
      %{
        state
        | leases: Map.put(state.leases, boundary_lease_view.boundary_ref, boundary_lease_view),
          lease_last_seen_at:
            Map.put(
              state.lease_last_seen_at,
              boundary_lease_view.boundary_ref,
              state.clock.utc_now()
            )
      }
    else
      updated_at = state.clock.utc_now()

      state
      |> Map.put(
        :leases,
        Map.put(state.leases, boundary_lease_view.boundary_ref, boundary_lease_view)
      )
      |> Map.put(
        :lease_last_seen_at,
        Map.put(state.lease_last_seen_at, boundary_lease_view.boundary_ref, updated_at)
      )
      |> Map.put(:boundary_epoch, state.boundary_epoch + 1)
      |> Map.put(:pending_epoch, state.boundary_epoch + 1)
      |> Map.put(:pending_updated_at, updated_at)
      |> schedule_flush()
    end
  end

  defp decision_relevant_boundary_view(nil), do: nil

  defp decision_relevant_boundary_view(%BoundaryLeaseView{} = boundary_lease_view) do
    {boundary_lease_view.boundary_ref, boundary_lease_view.staleness_status,
     boundary_lease_view.expires_at}
  end

  defp put_inflight(state, coalesce_key, inflight_entry) do
    %{state | inflight: Map.put(state.inflight, coalesce_key, inflight_entry)}
  end

  defp clear_inflight(state, coalesce_key) do
    case Map.get(state.inflight, coalesce_key) do
      nil ->
        %{state | inflight: Map.delete(state.inflight, coalesce_key)}

      inflight_entry ->
        cancel_timer_if_any(inflight_entry.ttl_timer_ref)
        cancel_timer_if_any(inflight_entry.retry_timer_ref)
        %{state | inflight: Map.delete(state.inflight, coalesce_key)}
    end
  end

  defp prepare_lease_capacity(state, boundary_ref) do
    state = sweep_expired_leases(state) |> elem(0)

    if Map.has_key?(state.leases, boundary_ref) or
         map_size(state.leases) < state.eviction_policy.max_leases_total do
      {:ok, state}
    else
      {:error,
       capacity_rejection(
         :lease_capacity_exhausted,
         :leases,
         map_size(state.leases),
         state.eviction_policy.max_leases_total
       ), state}
    end
  end

  defp prepare_inflight_capacity(state, coalesce_key) do
    {state, _count} = sweep_expired_inflight(state)

    if Map.has_key?(state.inflight, coalesce_key) or
         map_size(state.inflight) < state.eviction_policy.max_inflight_bootstraps_total do
      {:ok, state}
    else
      {:error,
       capacity_rejection(
         :bootstrap_capacity_exhausted,
         :inflight_bootstraps,
         map_size(state.inflight),
         state.eviction_policy.max_inflight_bootstraps_total
       ), state}
    end
  end

  defp prepare_circuit_capacity(state, key) do
    {state, _count} = sweep_expired_circuit_open_keys(state)

    if MapSet.member?(state.circuit_open_keys, key) or
         MapSet.size(state.circuit_open_keys) < state.eviction_policy.max_circuit_open_keys_total do
      {:ok, state}
    else
      {:error,
       capacity_rejection(
         :circuit_open_key_capacity_exhausted,
         :circuit_open_keys,
         MapSet.size(state.circuit_open_keys),
         state.eviction_policy.max_circuit_open_keys_total
       ), state}
    end
  end

  defp sweep_expired_state(state) do
    {state, leases} = sweep_expired_leases(state)
    {state, inflight} = sweep_expired_inflight(state)
    {state, circuit_open_keys} = sweep_expired_circuit_open_keys(state)

    {state, %{leases: leases, inflight: inflight, circuit_open_keys: circuit_open_keys}}
  end

  defp sweep_expired_leases(state) do
    candidates =
      state.leases
      |> Enum.filter(fn {boundary_ref, boundary_lease_view} ->
        lease_expired?(state, boundary_ref, boundary_lease_view)
      end)
      |> Enum.sort_by(fn {boundary_ref, _boundary_lease_view} ->
        Map.get(state.lease_last_seen_at, boundary_ref, state.clock.utc_now())
      end)

    boundary_refs =
      candidates
      |> Enum.take(state.eviction_policy.max_evictions_per_sweep)
      |> Enum.map(fn {boundary_ref, _boundary_lease_view} -> boundary_ref end)

    {%{
       state
       | leases: Map.drop(state.leases, boundary_refs),
         lease_last_seen_at: Map.drop(state.lease_last_seen_at, boundary_refs)
     }, length(boundary_refs)}
  end

  defp sweep_expired_inflight(state) do
    candidates =
      state.inflight
      |> Enum.filter(fn {_coalesce_key, inflight_entry} ->
        DateTime.diff(state.clock.utc_now(), inflight_entry.first_requested_at, :millisecond) >=
          state.eviction_policy.inflight_bootstrap_ttl_ms
      end)
      |> Enum.sort_by(fn {_coalesce_key, inflight_entry} -> inflight_entry.first_requested_at end)

    coalesce_keys =
      candidates
      |> Enum.take(state.eviction_policy.max_evictions_per_sweep)
      |> Enum.map(fn {coalesce_key, _inflight_entry} -> coalesce_key end)

    state =
      Enum.reduce(coalesce_keys, state, fn coalesce_key, state ->
        case Map.get(state.inflight, coalesce_key) do
          nil ->
            state

          inflight_entry ->
            Enum.each(inflight_entry.waiters, &GenServer.reply(&1, {:error, :bootstrap_timeout}))
            clear_inflight(state, coalesce_key)
        end
      end)

    {state, length(coalesce_keys)}
  end

  defp sweep_expired_circuit_open_keys(state) do
    candidates =
      state.circuit_opened_at
      |> Enum.filter(fn {key, opened_at} ->
        MapSet.member?(state.circuit_open_keys, key) and
          DateTime.diff(state.clock.utc_now(), opened_at, :millisecond) >=
            state.eviction_policy.circuit_open_ttl_ms
      end)
      |> Enum.sort_by(fn {_key, opened_at} -> opened_at end)

    keys =
      candidates
      |> Enum.take(state.eviction_policy.max_evictions_per_sweep)
      |> Enum.map(fn {key, _opened_at} -> key end)

    {%{
       state
       | circuit_open_keys: Enum.reduce(keys, state.circuit_open_keys, &MapSet.delete(&2, &1)),
         circuit_opened_at: Map.drop(state.circuit_opened_at, keys)
     }, length(keys)}
  end

  defp lease_expired?(state, boundary_ref, %BoundaryLeaseView{} = boundary_lease_view) do
    case boundary_lease_view.expires_at do
      %DateTime{} = expires_at ->
        lease_deadline_expired?(state, expires_at)

      nil ->
        DateTime.diff(
          state.clock.utc_now(),
          Map.get(state.lease_last_seen_at, boundary_ref, state.clock.utc_now()),
          :millisecond
        ) >= state.eviction_policy.lease_ttl_ms
    end
  end

  defp lease_deadline_expired?(state, %DateTime{} = expires_at) do
    DateTime.compare(expires_at, state.clock.utc_now()) != :gt
  end

  defp capacity_rejection(reason, segment, count, ceiling) do
    %{
      reason: reason,
      safe_action: :retry_after,
      retry_after_ms: 100,
      resource_exhaustion?: true,
      segment: segment,
      count: count,
      ceiling: ceiling
    }
  end

  defp coalesce_key(state, boundary_ref) do
    case state.classification_key_fun.(boundary_ref) do
      nil -> boundary_ref
      key -> key
    end
  end

  defp circuit_open?(state, key) do
    MapSet.member?(state.circuit_open_keys, key)
  end

  defp emit_circuit_open_telemetry(boundary_ref) do
    :telemetry.execute(
      Telemetry.event_name(:bridge_circuit_open),
      %{count: 1},
      %{
        bridge_family: :boundary,
        circuit_scope_class: :targeted_resume_bootstrap,
        boundary_ref: boundary_ref
      }
    )
  end

  defp emit_bootstrap_backlog_telemetry(inflight) do
    coalesced_request_count =
      inflight
      |> Map.values()
      |> Enum.map(& &1.coalesced_request_count)
      |> Enum.sum()

    :telemetry.execute(
      Telemetry.event_name(:boundary_bootstrap_backlog),
      %{count: map_size(inflight), coalesced_request_count: coalesced_request_count},
      %{}
    )
  end

  defp schedule_flush(%{flush_timer_ref: nil} = state) do
    %{
      state
      | flush_timer_ref: Process.send_after(self(), @flush_message, state.flush_interval_ms)
    }
  end

  defp schedule_flush(state), do: state

  defp schedule_eviction_sweep(state) do
    if state.eviction_policy.sweep_interval_ms > 0 do
      %{
        state
        | sweep_timer_ref:
            Process.send_after(
              self(),
              @eviction_sweep_message,
              state.eviction_policy.sweep_interval_ms
            )
      }
    else
      state
    end
  end

  defp cancel_timer_if_any(nil), do: :ok
  defp cancel_timer_if_any(timer_ref), do: Process.cancel_timer(timer_ref)

  defp normalize_eviction_policy(opts) when is_list(opts) do
    opts
    |> Map.new()
    |> normalize_eviction_policy()
  end

  defp normalize_eviction_policy(opts) when is_map(opts) do
    policy = Map.merge(@default_eviction_policy, opts)

    %{
      sweep_interval_ms: non_negative_integer!(policy.sweep_interval_ms, :sweep_interval_ms),
      max_evictions_per_sweep:
        positive_integer!(policy.max_evictions_per_sweep, :max_evictions_per_sweep),
      lease_ttl_ms: non_negative_integer!(policy.lease_ttl_ms, :lease_ttl_ms),
      inflight_bootstrap_ttl_ms:
        non_negative_integer!(policy.inflight_bootstrap_ttl_ms, :inflight_bootstrap_ttl_ms),
      circuit_open_ttl_ms:
        non_negative_integer!(policy.circuit_open_ttl_ms, :circuit_open_ttl_ms),
      max_leases_total: positive_integer!(policy.max_leases_total, :max_leases_total),
      max_inflight_bootstraps_total:
        positive_integer!(
          policy.max_inflight_bootstraps_total,
          :max_inflight_bootstraps_total
        ),
      max_circuit_open_keys_total:
        positive_integer!(
          policy.max_circuit_open_keys_total,
          :max_circuit_open_keys_total
        )
    }
  end

  defp positive_integer!(value, _field) when is_integer(value) and value > 0, do: value

  defp positive_integer!(value, field) do
    raise ArgumentError,
          "BoundaryLeaseTracker #{field} must be a positive integer, got: #{inspect(value)}"
  end

  defp non_negative_integer!(value, _field) when is_integer(value) and value >= 0, do: value

  defp non_negative_integer!(value, field) do
    raise ArgumentError,
          "BoundaryLeaseTracker #{field} must be a non-negative integer, got: #{inspect(value)}"
  end
end
