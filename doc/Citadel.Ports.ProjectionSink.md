# `Citadel.Ports.ProjectionSink`

Northbound publication seam for review and derived-state packets.

# `publish_derived_state_attachment`

```elixir
@callback publish_derived_state_attachment(
  Jido.Integration.V2.DerivedStateAttachment.t(),
  Citadel.ActionOutboxEntry.t()
) :: {:ok, String.t()} | {:error, atom()}
```

# `publish_review_projection`

```elixir
@callback publish_review_projection(
  Jido.Integration.V2.ReviewProjection.t(),
  Citadel.ActionOutboxEntry.t()
) ::
  {:ok, String.t()} | {:error, atom()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
