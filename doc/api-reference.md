# citadel v0.1.0 - API Reference

## Modules

- [Citadel.ActionOutboxEntry](Citadel.ActionOutboxEntry.md): Replay-safe persisted local action envelope.

- [Citadel.AttachGrant.V1](Citadel.AttachGrant.V1.md): Durable lower attach-grant fact normalized by `boundary_bridge`.

- [Citadel.AuthorityContract](Citadel.AuthorityContract.md): Packet-aligned ownership surface for the shared Brain authority packet.

- [Citadel.AuthorityContract.AuthorityDecision.V1](Citadel.AuthorityContract.AuthorityDecision.V1.md): Frozen `AuthorityDecision.v1` Brain authority packet.
- [Citadel.AuthorityDecision](Citadel.AuthorityDecision.md): Internal Brain authority value projected into `AuthorityDecision.v1`.

- [Citadel.BackoffPolicy](Citadel.BackoffPolicy.md): Explicit deterministic retry schedule contract.

- [Citadel.BoundaryBridge](Citadel.BoundaryBridge.md): Explicit boundary lifecycle seam for Brain-side boundary direction and lower lifecycle facts.

- [Citadel.BoundaryBridge.BoundaryProjectionAdapter](Citadel.BoundaryBridge.BoundaryProjectionAdapter.md): Isolates the boundary-intent projection shape at the bridge edge.

- [Citadel.BoundaryIntent](Citadel.BoundaryIntent.md): Frozen `BoundaryIntent` carrier shape owned by Citadel.

- [Citadel.BoundaryLeaseView](Citadel.BoundaryLeaseView.md): Host-local view of one boundary's liveness and reuse posture.

- [Citadel.BoundaryResumePolicy](Citadel.BoundaryResumePolicy.md): Explicit bounded targeted boundary-classification policy for attach or resume.

- [Citadel.BoundarySessionDescriptor.V1](Citadel.BoundarySessionDescriptor.V1.md): Durable lower boundary-session fact normalized by `boundary_bridge` and `query_bridge`.

- [Citadel.BridgeCircuit](Citadel.BridgeCircuit.md): Pure bridge-side circuit state keyed by the policy-selected downstream scope.

- [Citadel.BridgeCircuitPolicy](Citadel.BridgeCircuitPolicy.md): Explicit fail-fast policy for outbound bridge calls.

- [Citadel.BridgeState](Citadel.BridgeState.md): Process-backed owner for bridge circuit state and optional deduplication receipts.

- [Citadel.ContractCore](Citadel.ContractCore.md): Packet-aligned ownership surface for `core/contract_core`.

- [Citadel.ContractCore.CanonicalJson](Citadel.ContractCore.CanonicalJson.md): Canonical JSON normalization and RFC 8785 / JCS encoding helpers.
- [Citadel.Core](Citadel.Core.md): Packet-aligned ownership surface for `core/citadel_core`.

- [Citadel.CredentialHandleRef.V1](Citadel.CredentialHandleRef.V1.md): Lower credential-handle carrier owned below the Citadel invoke seam.

- [Citadel.DecisionHash](Citadel.DecisionHash.md): Canonical `decision_hash` implementation for `AuthorityDecision.v1`.
- [Citadel.DecisionRejection](Citadel.DecisionRejection.md): Explicit pure-core rejection result for valid but unplannable or disallowed work.

- [Citadel.DecisionRejectionClassifier](Citadel.DecisionRejectionClassifier.md): Pure rejection classification step driven by explicit policy-pack rules.

- [Citadel.DecisionSnapshot](Citadel.DecisionSnapshot.md): Immutable aggregate decision snapshot captured before a pure decision pass.

- [Citadel.ExecutionEvent.V1](Citadel.ExecutionEvent.V1.md): Raw lower execution fact consumed as an event.

- [Citadel.ExecutionGovernance.V1](Citadel.ExecutionGovernance.V1.md): Frozen `ExecutionGovernance.v1` Brain-to-Spine packet.
- [Citadel.ExecutionGovernanceCompiler](Citadel.ExecutionGovernanceCompiler.md): Pure compiler from existing Citadel decision values into `ExecutionGovernance.v1`.

- [Citadel.ExecutionGovernanceContract](Citadel.ExecutionGovernanceContract.md): Packet-aligned ownership surface for the Brain-to-Spine execution-governance packet.

- [Citadel.ExecutionIntentEnvelope.V1](Citadel.ExecutionIntentEnvelope.V1.md): Explicit Wave 5 handoff from `Citadel.InvocationRequest` into the lower execution packet family.

- [Citadel.ExecutionIntentEnvelope.V2](Citadel.ExecutionIntentEnvelope.V2.md): Successor lower execution handoff with typed execution-governance carriage.

- [Citadel.ExecutionOutcome.V1](Citadel.ExecutionOutcome.V1.md): Raw lower execution terminal fact consumed as an outcome.

- [Citadel.ExecutionRoute.V1](Citadel.ExecutionRoute.V1.md): Durable lower execution route fact.

- [Citadel.ExtensionAdmission](Citadel.ExtensionAdmission.md): Explicit admission result for one visible local service.

- [Citadel.HostIngress](Citadel.HostIngress.md): Public structured host-ingress seam above Citadel's runtime and lower bridge.

- [Citadel.HostIngress.Accepted](Citadel.HostIngress.Accepted.md): Typed successful result for the public host-ingress seam.

- [Citadel.HostIngress.InvocationCompiler](Citadel.HostIngress.InvocationCompiler.md): Pure compiler from structured host ingress into durable Citadel invocation work.

- [Citadel.HostIngress.InvocationPayload](Citadel.HostIngress.InvocationPayload.md): Canonical outbox payload codec for `submit_invocation` host-ingress entries.

- [Citadel.HostIngress.RequestContext](Citadel.HostIngress.RequestContext.md): Typed request context for the public structured host-ingress seam.

- [Citadel.HttpExecutionIntent.V1](Citadel.HttpExecutionIntent.V1.md): Initial provisional HTTP lower intent packet.

- [Citadel.IntentEnvelope](Citadel.IntentEnvelope.md): Frozen Wave 3 structured ingress contract for Citadel.

- [Citadel.IntentEnvelope.Constraints](Citadel.IntentEnvelope.Constraints.md): Structured planning and execution constraints carried by `Citadel.IntentEnvelope`.

- [Citadel.IntentEnvelope.DesiredOutcome](Citadel.IntentEnvelope.DesiredOutcome.md): Structured desired-outcome record carried by `Citadel.IntentEnvelope`.

- [Citadel.IntentEnvelope.RiskHint](Citadel.IntentEnvelope.RiskHint.md): Structured risk hint carried by `Citadel.IntentEnvelope`.

- [Citadel.IntentEnvelope.ScopeSelector](Citadel.IntentEnvelope.ScopeSelector.md): Structured scope selector carried by `Citadel.IntentEnvelope`.

- [Citadel.IntentEnvelope.SuccessCriterion](Citadel.IntentEnvelope.SuccessCriterion.md): Structured success criterion carried by `Citadel.IntentEnvelope`.

- [Citadel.IntentEnvelope.TargetHint](Citadel.IntentEnvelope.TargetHint.md): Structured target hint carried by `Citadel.IntentEnvelope`.

- [Citadel.IntentMappingConstraints](Citadel.IntentMappingConstraints.md): Frozen Wave 3 value-level mappings that later feed `BoundaryIntent` and `TopologyIntent`.

- [Citadel.InvocationBridge](Citadel.InvocationBridge.md): Explicit invocation bridge that stops at `Citadel.InvocationRequest.V2` and
projects the lower `ExecutionIntentEnvelope.V2` handoff locally.

- [Citadel.InvocationBridge.ExecutionIntentAdapter](Citadel.InvocationBridge.ExecutionIntentAdapter.md): Explicit adapter that freezes the `InvocationRequest.V2 -> ExecutionIntentEnvelope.V2`
handoff without pretending the lower family already exists downstream.

- [Citadel.InvocationRequest](Citadel.InvocationRequest.md): Frozen Citadel-owned invoke seam handed to `invocation_bridge`.
- [Citadel.InvocationRequest.V2](Citadel.InvocationRequest.V2.md): Successor Citadel-owned invoke seam with typed execution-governance carriage.

- [Citadel.JidoIntegrationBridge](Citadel.JidoIntegrationBridge.md): Citadel-owned transport seam for Brain-to-Spine durable submission.

- [Citadel.JidoIntegrationBridge.BrainInvocationAdapter](Citadel.JidoIntegrationBridge.BrainInvocationAdapter.md): Pure projection from Citadel's execution-intent handoff into the durable
`Jido.Integration.V2.BrainInvocation` packet.

- [Citadel.JidoIntegrationBridge.InvocationDownstream](Citadel.JidoIntegrationBridge.InvocationDownstream.md): Concrete downstream for `Citadel.InvocationBridge` that projects into the
durable `BrainInvocation` packet and delegates transport.

- [Citadel.JidoIntegrationBridge.LineageCodec](Citadel.JidoIntegrationBridge.LineageCodec.md): Mandatory choke point for reconstructing Citadel-local vendored
`Jido.Integration.V2` lineage structs.

- [Citadel.JsonRpcExecutionIntent.V1](Citadel.JsonRpcExecutionIntent.V1.md): Initial provisional JSON-RPC lower intent packet.

- [Citadel.KernelContext](Citadel.KernelContext.md): Canonical pre-planning context assembled from structured ingress and policy selection.

- [Citadel.KernelEpochUpdate](Citadel.KernelEpochUpdate.md): Explicit constituent epoch update emitted into `KernelSnapshot`.

- [Citadel.LocalAction](Citadel.LocalAction.md): Deferred post-commit local action.

- [Citadel.MemoryBridge](Citadel.MemoryBridge.md): Advisory memory bridge keyed lexically by `memory_id`.

- [Citadel.MemoryRecord](Citadel.MemoryRecord.md): Host-local advisory memory item surfaced through `Citadel.Ports.Memory`.

- [Citadel.Objective](Citadel.Objective.md): Normalized structured objective derived from `IntentEnvelope`.

- [Citadel.ObservabilityContract](Citadel.ObservabilityContract.md): Packet-aligned ownership surface for `core/observability_contract`.

- [Citadel.ObservabilityContract.Telemetry](Citadel.ObservabilityContract.Telemetry.md): Frozen low-cardinality telemetry event names, measurements, and metadata.

- [Citadel.ObservabilityContract.Trace](Citadel.ObservabilityContract.Trace.md): Frozen minimum trace vocabulary, correlation keys, and failure codes.

- [Citadel.PersistedSessionBlob](Citadel.PersistedSessionBlob.md): Single durable continuity write unit keyed by session id.

- [Citadel.PersistedSessionEnvelope](Citadel.PersistedSessionEnvelope.md): Versioned durable session continuity envelope.

- [Citadel.Plan](Citadel.Plan.md): Ordered plan for one objective.

- [Citadel.PlanHints](Citadel.PlanHints.md): Advisory plan shaping hints attached to structured ingress.

- [Citadel.PlanHints.BudgetHints](Citadel.PlanHints.BudgetHints.md): Budget hint used inside `Citadel.PlanHints`.

- [Citadel.PlanHints.CandidateStep](Citadel.PlanHints.CandidateStep.md): Candidate-step hint used inside `Citadel.PlanHints`.

- [Citadel.PlanHints.PreferredTopology](Citadel.PlanHints.PreferredTopology.md): Preferred-topology hint used inside `Citadel.PlanHints`.

- [Citadel.PolicyPacks](Citadel.PolicyPacks.md): Explicit policy-pack definitions and deterministic profile selection.

- [Citadel.PolicyPacks.PolicyPack](Citadel.PolicyPacks.PolicyPack.md): One explicit policy pack plus its selector, profile set, and rejection policy.

- [Citadel.PolicyPacks.Profiles](Citadel.PolicyPacks.Profiles.md): Explicit decision-shaping profiles selected from one policy pack.

- [Citadel.PolicyPacks.RejectionPolicy](Citadel.PolicyPacks.RejectionPolicy.md): Pure policy inputs for rejection retryability and publication classification.

- [Citadel.PolicyPacks.Selection](Citadel.PolicyPacks.Selection.md): Deterministic output of policy-pack profile selection.

- [Citadel.PolicyPacks.Selector](Citadel.PolicyPacks.Selector.md): Explicit policy-pack selector inputs.

- [Citadel.Ports.BoundaryLifecycle](Citadel.Ports.BoundaryLifecycle.md): Projects boundary intent and normalizes boundary lifecycle facts.

- [Citadel.Ports.Clock](Citadel.Ports.Clock.md): Small local clock capability used by runtime owners and adapters.

- [Citadel.Ports.Id](Citadel.Ports.Id.md): Small bounded local id capability.

- [Citadel.Ports.IntentResolver](Citadel.Ports.IntentResolver.md): Optional host-facing structured ingress resolver above the kernel.

- [Citadel.Ports.InvocationSink](Citadel.Ports.InvocationSink.md): Host-local invocation seam consumed by runtime after commit.

- [Citadel.Ports.Memory](Citadel.Ports.Memory.md): Advisory memory seam keyed lexically by `memory_id`.

- [Citadel.Ports.ProjectionSink](Citadel.Ports.ProjectionSink.md): Northbound publication seam for review and derived-state packets.

- [Citadel.Ports.RuntimeQuery](Citadel.Ports.RuntimeQuery.md): Rehydrates durable lower truth into normalized Citadel read models.

- [Citadel.Ports.SignalSource](Citadel.Ports.SignalSource.md): Normalizes runtime signals into `Citadel.RuntimeObservation`.

- [Citadel.Ports.Trace](Citadel.Ports.Trace.md): Frozen minimum trace publication seam.

- [Citadel.ProcessExecutionIntent.V1](Citadel.ProcessExecutionIntent.V1.md): Initial provisional process lower intent packet.

- [Citadel.ProjectBinding](Citadel.ProjectBinding.md): Durable host-local binding between a session and project/workspace.

- [Citadel.ProjectionBridge](Citadel.ProjectionBridge.md): Explicit northbound publication bridge for review projections and derived-state attachments.

- [Citadel.ProjectionBridge.DerivedStateAttachmentAdapter](Citadel.ProjectionBridge.DerivedStateAttachmentAdapter.md): Isolates `DerivedStateAttachment` contract-shape evolution at the bridge edge.

- [Citadel.ProjectionBridge.ReviewProjectionAdapter](Citadel.ProjectionBridge.ReviewProjectionAdapter.md): Isolates `ReviewProjection` contract-shape evolution at the bridge edge.

- [Citadel.QueryBridge](Citadel.QueryBridge.md): Rehydrates durable lower truth into normalized Citadel read models.

- [Citadel.ResolutionProvenance](Citadel.ResolutionProvenance.md): Explicit provenance for how a structured `IntentEnvelope` was formed.

- [Citadel.Runtime](Citadel.Runtime.md): Packet-aligned ownership surface for `core/citadel_runtime`.

- [Citadel.Runtime.BoundaryLeaseTracker](Citadel.Runtime.BoundaryLeaseTracker.md): Host-local boundary liveness and targeted resume-classification owner.

- [Citadel.Runtime.KernelSnapshot](Citadel.Runtime.KernelSnapshot.md): Single serialized writer for aggregate `DecisionSnapshot` publication.
- [Citadel.Runtime.ObservationSignalSource](Citadel.Runtime.ObservationSignalSource.md): Default runtime signal source for already-normalized observations.
- [Citadel.Runtime.PolicyCache](Citadel.Runtime.PolicyCache.md): Host-local mutable policy snapshot owner.

- [Citadel.Runtime.ScopeCatalog](Citadel.Runtime.ScopeCatalog.md): Host-local scope and target visibility owner.

- [Citadel.Runtime.ServiceCatalog](Citadel.Runtime.ServiceCatalog.md): Host-local dynamic service visibility and admission owner.

- [Citadel.Runtime.SessionDirectory](Citadel.Runtime.SessionDirectory.md): Continuity-store owner for persisted session blobs, activation policy, and
dead-letter maintenance.

- [Citadel.Runtime.SessionMigration](Citadel.Runtime.SessionMigration.md): Explicit bounded migration for persisted session continuity blobs.

- [Citadel.Runtime.SessionServer](Citadel.Runtime.SessionServer.md): Dynamic owner for one session's mutable host-local runtime state.

- [Citadel.Runtime.SignalIngress](Citadel.Runtime.SignalIngress.md): Always-on signal ingress root with per-session logical subscription isolation.

- [Citadel.Runtime.TopologyCatalog](Citadel.Runtime.TopologyCatalog.md): Host-local topology defaults and routing-constraint owner.

- [Citadel.Runtime.TracePublisher](Citadel.Runtime.TracePublisher.md): Best-effort bounded trace publisher used after commit.
- [Citadel.Runtime.TracePublisher.Buffer](Citadel.Runtime.TracePublisher.Buffer.md): Segmented bounded buffer preserving a protected error-family evidence window.

- [Citadel.RuntimeObservation](Citadel.RuntimeObservation.md): Host-local normalized observation produced from query or signal ingress.

- [Citadel.ScopeRef](Citadel.ScopeRef.md): Explicit host-local scope reference for kernel interpretation.

- [Citadel.ServiceDescriptor](Citadel.ServiceDescriptor.md): Explicit visible service descriptor.

- [Citadel.SessionActivationPolicy](Citadel.SessionActivationPolicy.md): Explicit bounded cold-boot or mass-recovery activation policy.

- [Citadel.SessionContinuityCommit](Citadel.SessionContinuityCommit.md): Single atomic continuity-write command crossing the `SessionDirectory` seam.

- [Citadel.SessionOutbox](Citadel.SessionOutbox.md): Live in-memory session outbox working set with explicit one-to-one invariants.

- [Citadel.SessionState](Citadel.SessionState.md): Live mutable session state reconstructed from persisted continuity plus local visibility.

- [Citadel.SignalBridge](Citadel.SignalBridge.md): Normalizes non-boundary runtime signals into `Citadel.RuntimeObservation`.

- [Citadel.SignalIngressRebuildPolicy](Citadel.SignalIngressRebuildPolicy.md): Explicit rebuild policy for `SignalIngress`.

- [Citadel.StalenessRequirements](Citadel.StalenessRequirements.md): Explicit replay-safe stale-check contract for one persisted action.

- [Citadel.Step](Citadel.Step.md): One explicit planned step.

- [Citadel.TargetResolution](Citadel.TargetResolution.md): Explicit result of host-local target resolution.

- [Citadel.TopologyIntent](Citadel.TopologyIntent.md): Frozen `TopologyIntent` carrier shape owned by Citadel.

- [Citadel.TraceBridge](Citadel.TraceBridge.md): AITrace-facing trace publication bridge consuming canonical `Citadel.TraceEnvelope` values.

- [Citadel.TraceEnvelope](Citadel.TraceEnvelope.md): Canonical Citadel-owned trace publication value.

- [Jido.Integration.V2.AuthorityAuditEnvelope](Jido.Integration.V2.AuthorityAuditEnvelope.md): Spine-owned machine-readable authority audit payload derived from the Brain packet.

- [Jido.Integration.V2.BrainInvocation](Jido.Integration.V2.BrainInvocation.md): Durable Brain-to-Spine invocation handoff packet.

- [Jido.Integration.V2.CanonicalJson](Jido.Integration.V2.CanonicalJson.md): Spine-owned canonical JSON normalization and RFC 8785 / JCS encoding helpers.

- [Jido.Integration.V2.Contracts](Jido.Integration.V2.Contracts.md): Shared public types and validation helpers for the greenfield integration platform.

- [Jido.Integration.V2.DerivedStateAttachment](Jido.Integration.V2.DerivedStateAttachment.md): Canonical attachment contract for higher-order derived state.
- [Jido.Integration.V2.EvidenceRef](Jido.Integration.V2.EvidenceRef.md): Stable reference to a source record backing a packet, decision, or interpretation.

- [Jido.Integration.V2.ExecutionGovernanceProjection](Jido.Integration.V2.ExecutionGovernanceProjection.md): Spine-owned machine-readable governance projection carried in Brain submissions.

- [Jido.Integration.V2.ExecutionGovernanceProjection.Compiler](Jido.Integration.V2.ExecutionGovernanceProjection.Compiler.md): Compiles Spine-owned governance projections into operational shadow sections.

- [Jido.Integration.V2.ExecutionGovernanceProjection.Verifier](Jido.Integration.V2.ExecutionGovernanceProjection.Verifier.md): Verifies that supplied operational shadow sections still match the Spine compiler.

- [Jido.Integration.V2.GovernanceRef](Jido.Integration.V2.GovernanceRef.md): Stable reference to governance lineage such as approval, denial, override, rollback, or policy decisions.

- [Jido.Integration.V2.ReviewProjection](Jido.Integration.V2.ReviewProjection.md): Contracts-only northbound review projection carried in review packet metadata.

- [Jido.Integration.V2.SubjectRef](Jido.Integration.V2.SubjectRef.md): Stable reference to the primary node-local subject a higher-order record is about.

- [Jido.Integration.V2.SubmissionAcceptance](Jido.Integration.V2.SubmissionAcceptance.md): Durable Spine acceptance receipt for a Brain submission.

- [Jido.Integration.V2.SubmissionIdentity](Jido.Integration.V2.SubmissionIdentity.md): Spine-owned stable identity for a durable Brain submission.

- [Jido.Integration.V2.SubmissionRejection](Jido.Integration.V2.SubmissionRejection.md): Typed Spine rejection for a Brain submission.

