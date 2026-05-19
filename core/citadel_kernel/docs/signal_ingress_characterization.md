# Signal Ingress Characterization

This guide records the Phase 27 behavior contract for
`Citadel.Kernel.SignalIngress`. Phase 28 may split the implementation, but it
must preserve these contracts unless a later phase explicitly changes and tests
the public behavior.

## Current Responsibilities

- Admission: normalize the admission policy, reject missing partition fields,
  reject missing lineage fields, reject regressed source positions/revisions,
  enforce token bucket, queue-depth, tenant in-flight, and partition-count
  caps, and emit admission rejection telemetry.
- Partition routing: derive a partition ref, partition key, tenant scope,
  delivery order scope, dedupe key, and lineage from a normalized
  `RuntimeObservation`.
- Subscription storage: register, unregister, rebuild, and snapshot
  subscription state, consumer state, last-seen data, source anchors, and
  cursor advancement.
- Delivery: admit synchronously, hand off actual consumer calls to a
  partition worker, release queue and tenant reservations after delivery, and
  mark partitions overloaded after delivery timeouts.
- Eviction: sweep inactive subscriptions, dead consumers, expired rebuild
  queue entries, and idle partitions under bounded caps.
- Rebuild: load active session cursors from `SessionDirectory`, batch them by
  priority, group transport repositioning, and publish rebuild telemetry.
- Supervision: `SignalIngress` owns logical partition state, while
  `SignalIngress.PartitionWorker` instances are `DynamicSupervisor` children
  under `Citadel.Kernel.SignalIngress.PartitionSupervisor` or an explicitly
  supplied test supervisor.

## Existing Characterization Tests

- `signal_ingress_partition_test.exs`: admission, partition routing, token
  buckets, tenant in-flight caps, lineage requirements, source regression,
  async handoff, delivery timeout overload, and replay evidence.
- `segmented_lru_eviction_test.exs`: subscription, consumer, rebuild queue,
  partition, session, and boundary lease eviction behavior.
- `runtime_coordination_test.exs`: directory rebuild and priority batch
  behavior in the broader runtime coordination flow.
- `telemetry_assurance_test.exs`: telemetry contract shapes for rebuild,
  high-priority readiness, lag, rejection, and overload events.
- `observation_signal_source_test.exs`: normalized observation source
  boundary and public `deliver_observation/2` route.
- `signal_ingress_characterization_test.exs`: storage/unregister semantics,
  no-consumer delivery, cursor/source-anchor advancement, and partition-worker
  supervision expectations.

## Phase 28 Extraction Boundaries

- `SignalIngress.AdmissionPolicy`: policy normalization and validation.
- `SignalIngress.PartitionRouter`: observation-to-partition derivation,
  lineage extraction, dedupe key derivation, and source-anchor regression
  checks.
- `SignalIngress.AdmissionGate`: token bucket, queue-depth, tenant in-flight,
  partition capacity, and rejection evidence.
- `SignalIngress.SubscriptionRegistry`: subscription, consumer, cursor,
  source-anchor, and last-seen state transitions.
- `SignalIngress.RebuildQueue`: directory cursor import, batch ordering,
  transport grouping, and rebuild backlog telemetry.
- `SignalIngress.EvictionPolicy`: TTL/cap configuration and bounded sweep
  candidate selection.
- `SignalIngress.EvictionEngine`: subscription, consumer, rebuild-queue, and
  idle-partition eviction state transitions.
- `SignalIngress.DeliveryEngine`: accepted evidence, delivery result,
  overload telemetry, and reservation release.
- `SignalIngress.PartitionWorker`: move to its own file with `child_spec/1`
  and `start_link/1` as the supervised entrypoints.

The top-level `SignalIngress` GenServer should remain the owner/coordinator for
state, timers, and public calls. Extraction modules should be pure where
possible and should not introduce new processes.
