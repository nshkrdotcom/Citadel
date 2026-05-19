defmodule Citadel.Kernel.SignalIngressCharacterizationTest do
  use ExUnit.Case, async: false

  alias Citadel.Kernel.SignalIngress
  alias Citadel.RuntimeObservation
  alias Jido.Integration.V2.SubjectRef

  defmodule TestSignalSource do
    @behaviour Citadel.Ports.SignalSource

    @impl true
    def normalize_signal(%RuntimeObservation{} = observation), do: {:ok, observation}
  end

  test "subscription storage keeps tenant scope and unregister removes consumer state" do
    signal_ingress = start_signal_ingress()
    consumer = start_supervised!({__MODULE__.RecordingConsumer, test_pid: self()})

    assert :ok =
             SignalIngress.register_subscription(signal_ingress, "sess-storage",
               subscription_ref: "subscription/custom",
               committed_signal_cursor: "cursor/1",
               transport_cursor: "transport/1",
               tenant_id: "tenant-a",
               authority_scope: "authority-a",
               priority_class: "live_request",
               extensions: %{"source_revision" => "rev-1"}
             )

    assert :ok = SignalIngress.register_consumer(signal_ingress, "sess-storage", consumer)

    assert %{
             subscription_ref: "subscription/custom",
             committed_signal_cursor: "cursor/1",
             transport_cursor: "transport/1",
             tenant_scope_key: {"tenant-a", "authority-a"},
             priority_class: "live_request",
             extensions: %{"source_revision" => "rev-1"}
           } = SignalIngress.subscription_state(signal_ingress, "sess-storage")

    snapshot = SignalIngress.snapshot(signal_ingress)
    assert snapshot.consumers["sess-storage"] == consumer
    assert Map.has_key?(snapshot.consumer_last_seen_at, "sess-storage")

    assert :ok = SignalIngress.unregister_subscription(signal_ingress, "sess-storage")
    assert SignalIngress.subscription_state(signal_ingress, "sess-storage") == nil

    snapshot = SignalIngress.snapshot(signal_ingress)
    refute Map.has_key?(snapshot.consumers, "sess-storage")
    refute Map.has_key?(snapshot.consumer_last_seen_at, "sess-storage")
  end

  test "delivery without a registered consumer still admits and advances subscription cursor" do
    signal_ingress = start_signal_ingress()
    assert :ok = SignalIngress.register_subscription(signal_ingress, "sess-unclaimed")

    assert {:ok, acceptance} =
             SignalIngress.deliver_observation(
               signal_ingress,
               observation("sess-unclaimed", "sig-unclaimed", subject_id: "subject-unclaimed")
             )

    assert acceptance.async_handoff? == true
    assert acceptance.queue_depth == 1
    assert acceptance.partition_key.tenant_id == "tenant-1"

    wait_until(fn ->
      snapshot = SignalIngress.snapshot(signal_ingress)
      Map.get(snapshot.partition_queue_depths, acceptance.partition_ref, 0) == 0
    end)

    assert %{
             transport_cursor: "cursor/sig-unclaimed",
             extensions: %{
               "lineage_source_anchor" => %{
                 "kind" => "source_position",
                 "value" => "cursor/sig-unclaimed"
               }
             }
           } = SignalIngress.subscription_state(signal_ingress, "sess-unclaimed")
  end

  test "partition worker is a DynamicSupervisor child and exits when its owner exits" do
    supervisor = unique_name(:partition_worker_supervisor)
    start_supervised!({DynamicSupervisor, strategy: :one_for_one, name: supervisor})

    owner =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    assert {:ok, worker} =
             DynamicSupervisor.start_child(
               supervisor,
               {SignalIngress.PartitionWorker, owner: owner, partition_ref: {:subject, "tenant"}}
             )

    assert is_pid(worker)

    assert [{_child_id, ^worker, :worker, [SignalIngress.PartitionWorker]}] =
             DynamicSupervisor.which_children(supervisor)

    ref = Process.monitor(worker)
    send(owner, :stop)
    assert_receive {:DOWN, ^ref, :process, ^worker, :normal}, 500
  end

  defmodule RecordingConsumer do
    use GenServer

    def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

    @impl true
    def init(opts), do: {:ok, %{test_pid: Keyword.fetch!(opts, :test_pid)}}

    @impl true
    def handle_call({:record_runtime_observation, observation}, _from, state) do
      send(state.test_pid, {:consumer_recorded, observation.signal_id})
      {:reply, :ok, state}
    end
  end

  defp start_signal_ingress(opts \\ []) do
    name = unique_name(:signal_ingress)
    partition_worker_supervisor = unique_name(:partition_worker_supervisor)

    start_supervised!(
      {DynamicSupervisor, strategy: :one_for_one, name: partition_worker_supervisor}
    )

    start_supervised!(
      {SignalIngress,
       Keyword.merge(
         [
           name: name,
           signal_source: TestSignalSource,
           partition_worker_supervisor: partition_worker_supervisor,
           admission_policy: [
             bucket_capacity: 16,
             refill_rate_per_second: 0,
             max_queue_depth_per_partition: 16,
             max_in_flight_per_tenant_scope: 16,
             retry_after_ms: 100,
             delivery_order_scope: :partition_fifo
           ],
           eviction_policy: [sweep_interval_ms: 0]
         ],
         opts
       )}
    )

    name
  end

  defp observation(session_id, signal_id, opts) do
    subject_id = Keyword.fetch!(opts, :subject_id)

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
      extensions: %{
        "tenant_id" => "tenant-1",
        "authority_scope" => "authority-1",
        "trace_id" => "trace/#{signal_id}",
        "causation_id" => "cause/#{signal_id}",
        "canonical_idempotency_key" => "idem:v1:#{signal_id}"
      }
    })
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

  defp unique_name(prefix),
    do: {:global, {__MODULE__, prefix, System.unique_integer([:positive, :monotonic])}}
end
