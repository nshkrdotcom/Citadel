# `Citadel.ObservabilityContract.Trace`

Frozen minimum trace vocabulary, correlation keys, and failure codes.

# `canonical_event_name!`

```elixir
@spec canonical_event_name!(String.t()) :: String.t()
```

# `canonical_event_names`

```elixir
@spec canonical_event_names() :: map()
```

# `failure_reason_codes`

```elixir
@spec failure_reason_codes() :: [atom(), ...]
```

# `family_classification`

```elixir
@spec family_classification(String.t()) :: :protected_error | :default
```

# `known_family?`

```elixir
@spec known_family?(String.t()) :: boolean()
```

# `protected_error_families`

```elixir
@spec protected_error_families() :: [String.t(), ...]
```

# `protected_error_family?`

```elixir
@spec protected_error_family?(String.t()) :: boolean()
```

# `record_kinds`

```elixir
@spec record_kinds() :: [atom(), ...]
```

# `required_correlation_keys`

```elixir
@spec required_correlation_keys() :: [atom(), ...]
```

# `required_event_families`

```elixir
@spec required_event_families() :: [String.t(), ...]
```

# `required_event_family?`

```elixir
@spec required_event_family?(String.t()) :: boolean()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
