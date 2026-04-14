# `Citadel.RuntimeObservation`

Host-local normalized observation produced from query or signal ingress.

# `t`

```elixir
@type t() :: %Citadel.RuntimeObservation{
  artifacts: [term()],
  event_at: DateTime.t(),
  event_kind: String.t(),
  evidence_refs: [Jido.Integration.V2.EvidenceRef.t()],
  extensions: map(),
  governance_refs: [Jido.Integration.V2.GovernanceRef.t()],
  observation_id: String.t(),
  output: term(),
  payload: map(),
  request_id: String.t() | nil,
  runtime_ref_id: String.t(),
  session_id: String.t(),
  signal_cursor: String.t() | nil,
  signal_id: String.t(),
  status: String.t() | nil,
  subject_ref: Jido.Integration.V2.SubjectRef.t()
}
```

# `dump`

# `new!`

# `read_descriptor`

Returns the stable structured read descriptor for one observation.

# `schema`

# `stable_read_fields`

Returns the stable upper-consumer field set for structured runtime reads.

# `wake_reason`

Returns the wake reason surface used by semantic and northbound consumers.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
