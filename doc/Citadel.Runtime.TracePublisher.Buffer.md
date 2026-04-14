# `Citadel.Runtime.TracePublisher.Buffer`

Segmented bounded buffer preserving a protected error-family evidence window.

# `queued_envelope`

```elixir
@type queued_envelope() :: {non_neg_integer(), Citadel.TraceEnvelope.t()}
```

# `t`

```elixir
@type t() :: %Citadel.Runtime.TracePublisher.Buffer{
  next_seq: non_neg_integer(),
  protected_capacity: non_neg_integer(),
  protected_len: non_neg_integer(),
  protected_queue: :queue.queue(queued_envelope()),
  regular_capacity: non_neg_integer(),
  regular_len: non_neg_integer(),
  regular_queue: :queue.queue(queued_envelope()),
  total_capacity: pos_integer()
}
```

# `depth`

```elixir
@spec depth(t()) :: non_neg_integer()
```

# `depths`

```elixir
@spec depths(t()) :: %{
  depth: non_neg_integer(),
  protected_depth: non_neg_integer(),
  regular_depth: non_neg_integer()
}
```

# `enqueue`

```elixir
@spec enqueue(t(), Citadel.TraceEnvelope.t()) ::
  {t(), Citadel.TraceEnvelope.t() | nil}
```

# `new!`

```elixir
@spec new!(keyword()) :: t()
```

# `take_batch`

```elixir
@spec take_batch(t(), pos_integer()) :: {[Citadel.TraceEnvelope.t()], t()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
