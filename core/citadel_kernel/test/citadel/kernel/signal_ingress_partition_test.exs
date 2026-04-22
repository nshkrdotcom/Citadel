defmodule Citadel.Kernel.SignalIngressPartitionTest do
  use ExUnit.Case, async: false

  alias Citadel.Kernel.SignalIngress
  alias Citadel.ObservabilityContract.Telemetry
  alias Citadel.RuntimeObservation
  alias Jido.Integration.V2.SubjectRef

  defmodule TestSignalSource do
    @behaviour Citadel.Ports.SignalSource

    @impl true
    def normalize_signal(%RuntimeObservation{} = observation), do: {:ok, observation}
  end

  defmodule BlockingConsumer do
    use GenServer

    def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

    @impl true
    def init(opts), do: {:ok, %{test_pid: Keyword.fetch!(opts, :test_pid)}}

    @impl true
    def handle_call({:record_runtime_observation, observation}, _from, state) do
      send(state.test_pid, {:consumer_blocked, observation.signal_id, self()})

      receive do
        {:release_consumer, signal_id} when signal_id == observation.signal_id ->
          {:reply, :ok, state}
      after
        2_000 ->
          {:reply, {:error, :timeout}, state}
      end
    end
  end

  defmodule RecordingConsumer do
    use GenServer

    def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

    @impl true
    def init(opts), do: {:ok, %{test_pid: Keyword.fetch!(opts, :test_pid)}}

    @impl true
    def handle_call({:record_runtime_observation, observation}, _from, state) do
      send(state.test_pid, {:consumer_recorded, observation.signal_id, self()})
      {:reply, :ok, state}
    end
  end

  defmodule TelemetryForwarder do
    def handle_event(event_name, measurements, metadata, test_pid) do
      send(test_pid, {:telemetry_event, event_name, measurements, metadata})
    end
  end

  test "deliver_signal admits synchronously and hands off delivery to isolated partition workers" do
    signal_ingress = start_signal_ingress(admission_policy: generous_admission_policy())
    blocking_consumer = start_supervised!({BlockingConsumer, test_pid: self()})
    recording_consumer = start_supervised!({RecordingConsumer, test_pid: self()})

    assert :ok = SignalIngress.register_subscription(signal_ingress, "sess-blocked")
    assert :ok = SignalIngress.register_subscription(signal_ingress, "sess-open")

    assert :ok =
             SignalIngress.register_consumer(signal_ingress, "sess-blocked", blocking_consumer)

    assert :ok = SignalIngress.register_consumer(signal_ingress, "sess-open", recording_consumer)

    blocked_task =
      Task.async(fn ->
        SignalIngress.deliver_observation(
          signal_ingress,
          observation("sess-blocked", "sig-blocked", subject_id: "subject-blocked")
        )
      end)

    assert {:ok, blocked_acceptance} = Task.await(blocked_task, 100)
    assert blocked_acceptance.async_handoff? == true
    assert blocked_acceptance.delivery_order_scope == :partition_fifo
    assert blocked_acceptance.partition_key.tenant_id == "tenant-1"
    assert blocked_acceptance.partition_key.authority_scope == "authority-1"
    assert blocked_acceptance.partition_key.subject_ref.id == "subject-blocked"
    assert is_pid(blocked_acceptance.partition_worker)

    assert_receive {:consumer_blocked, "sig-blocked", _consumer_pid}, 500

    assert {:ok, open_acceptance} =
             SignalIngress.deliver_observation(
               signal_ingress,
               observation("sess-open", "sig-open", subject_id: "subject-open")
             )

    assert open_acceptance.partition_ref != blocked_acceptance.partition_ref
    assert_receive {:consumer_recorded, "sig-open", _consumer_pid}, 500

    snapshot = SignalIngress.snapshot(signal_ingress)
    assert snapshot.partition_queue_depths[blocked_acceptance.partition_ref] == 1

    wait_until(fn ->
      snapshot = SignalIngress.snapshot(signal_ingress)
      Map.get(snapshot.partition_queue_depths, open_acceptance.partition_ref, 0) == 0
    end)

    send(blocking_consumer, {:release_consumer, "sig-blocked"})

    wait_until(fn ->
      snapshot = SignalIngress.snapshot(signal_ingress)
      Map.get(snapshot.partition_queue_depths, blocked_acceptance.partition_ref, 0) == 0
    end)
  end

  test "token-bucket exhaustion rejects before queue insertion with retry-after evidence" do
    signal_ingress =
      start_signal_ingress(
        admission_policy:
          Keyword.merge(generous_admission_policy(),
            bucket_capacity: 1,
            refill_rate_per_second: 0,
            retry_after_ms: 250
          )
      )

    observation = observation("sess-token", "sig-token-1", subject_id: "subject-token")
    assert {:ok, accepted} = SignalIngress.deliver_observation(signal_ingress, observation)

    wait_until(fn ->
      snapshot = SignalIngress.snapshot(signal_ingress)
      Map.get(snapshot.partition_queue_depths, accepted.partition_ref, 0) == 0
    end)

    attach_telemetry(self(), [:signal_ingress_admission_rejection])

    assert {:error, rejection} =
             SignalIngress.deliver_observation(
               signal_ingress,
               observation("sess-token", "sig-token-2", subject_id: "subject-token")
             )

    assert rejection.reason == :partition_token_exhausted
    assert rejection.resource_exhaustion? == true
    assert rejection.retry_after_ms == 250
    assert rejection.queue_depth_before == 0
    assert rejection.queue_depth_after == 0

    assert_receive {:telemetry_event, event_name, measurements, metadata}, 500
    assert event_name == Telemetry.event_name(:signal_ingress_admission_rejection)
    assert_contract_shape(:signal_ingress_admission_rejection, measurements, metadata)
    assert metadata.reason_code == :partition_token_exhausted
  end

  test "tenant-scope cap rejection and missing partition fields fail before enqueue" do
    signal_ingress =
      start_signal_ingress(
        admission_policy:
          Keyword.merge(generous_admission_policy(),
            max_in_flight_per_tenant_scope: 1,
            retry_after_ms: 300
          )
      )

    blocking_consumer = start_supervised!({BlockingConsumer, test_pid: self()})
    assert :ok = SignalIngress.register_subscription(signal_ingress, "sess-held")
    assert :ok = SignalIngress.register_consumer(signal_ingress, "sess-held", blocking_consumer)

    assert {:ok, held_acceptance} =
             SignalIngress.deliver_observation(
               signal_ingress,
               observation("sess-held", "sig-held", subject_id: "subject-held")
             )

    assert_receive {:consumer_blocked, "sig-held", _consumer_pid}, 500

    assert {:error, cap_rejection} =
             SignalIngress.deliver_observation(
               signal_ingress,
               observation("sess-other", "sig-other", subject_id: "subject-other")
             )

    assert cap_rejection.reason == :tenant_scope_in_flight_exhausted
    assert cap_rejection.retry_after_ms == 300
    assert cap_rejection.queue_depth_before == 0
    assert cap_rejection.queue_depth_after == 0

    assert {:error, missing_key_rejection} =
             SignalIngress.deliver_observation(
               signal_ingress,
               observation("sess-missing", "sig-missing", tenant_id: nil)
             )

    assert missing_key_rejection.reason == :missing_partition_key_fields
    assert :tenant_id in missing_key_rejection.missing_fields
    refute missing_key_rejection.resource_exhaustion?

    send(blocking_consumer, {:release_consumer, "sig-held"})

    wait_until(fn ->
      snapshot = SignalIngress.snapshot(signal_ingress)
      Map.get(snapshot.partition_queue_depths, held_acceptance.partition_ref, 0) == 0
    end)
  end

  defp start_signal_ingress(opts) do
    name = unique_name(:signal_ingress)

    start_supervised!(
      {SignalIngress, Keyword.merge([name: name, signal_source: TestSignalSource], opts)}
    )

    name
  end

  defp generous_admission_policy do
    [
      bucket_capacity: 16,
      refill_rate_per_second: 0,
      max_queue_depth_per_partition: 16,
      max_in_flight_per_tenant_scope: 16,
      retry_after_ms: 100,
      delivery_order_scope: :partition_fifo
    ]
  end

  defp observation(session_id, signal_id, opts) do
    tenant_id = Keyword.get(opts, :tenant_id, "tenant-1")
    authority_scope = Keyword.get(opts, :authority_scope, "authority-1")
    subject_id = Keyword.get(opts, :subject_id, session_id)

    RuntimeObservation.new!(%{
      observation_id: "obs/#{signal_id}",
      request_id: "req/#{signal_id}",
      session_id: session_id,
      signal_id: signal_id,
      signal_cursor: "cursor/#{signal_id}",
      runtime_ref_id: "runtime/#{session_id}",
      event_kind: "host_signal",
      event_at: DateTime.utc_now(),
      status: "ok",
      output: %{},
      artifacts: [],
      payload: %{"status" => "ok"},
      subject_ref: SubjectRef.new!(%{kind: :run, id: subject_id, metadata: %{}}),
      evidence_refs: [],
      governance_refs: [],
      extensions:
        %{}
        |> maybe_put("tenant_id", tenant_id)
        |> maybe_put("authority_scope", authority_scope)
    })
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp attach_telemetry(test_pid, telemetry_names) do
    handler_id = "signal-ingress-partition-test-#{System.unique_integer([:positive])}"

    :ok =
      :telemetry.attach_many(
        handler_id,
        Enum.map(telemetry_names, &Telemetry.event_name/1),
        &TelemetryForwarder.handle_event/4,
        test_pid
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end

  defp assert_contract_shape(telemetry_name, measurements, metadata) do
    assert Enum.sort(Map.keys(measurements)) ==
             telemetry_name |> Telemetry.measurement_keys() |> Enum.sort()

    assert Enum.sort(Map.keys(metadata)) ==
             telemetry_name |> Telemetry.metadata_keys() |> Enum.sort()
  end

  defp wait_until(fun, attempts \\ 40)

  defp wait_until(fun, attempts) when attempts > 0 do
    if fun.() do
      :ok
    else
      Process.sleep(10)
      wait_until(fun, attempts - 1)
    end
  end

  defp wait_until(_fun, 0), do: flunk("condition did not become true in time")

  defp unique_name(prefix), do: :"#{prefix}_#{System.unique_integer([:positive, :monotonic])}"
end
