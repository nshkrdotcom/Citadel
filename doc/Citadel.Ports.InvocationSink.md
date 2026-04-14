# `Citadel.Ports.InvocationSink`

Host-local invocation seam consumed by runtime after commit.

# `submission_result`

```elixir
@type submission_result() ::
  {:accepted, Jido.Integration.V2.SubmissionAcceptance.t()}
  | {:rejected, Jido.Integration.V2.SubmissionRejection.t()}
  | {:error, atom()}
```

# `submit_invocation`

```elixir
@callback submit_invocation(
  Citadel.InvocationRequest.V2.t(),
  Citadel.ActionOutboxEntry.t()
) ::
  submission_result()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
