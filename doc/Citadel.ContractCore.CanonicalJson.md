# `Citadel.ContractCore.CanonicalJson`

Canonical JSON normalization and RFC 8785 / JCS encoding helpers.

Shared packet hashing flows through this module so Citadel code can normalize
packet values explicitly before `Jcs.encode/1` without relying on
implementation-defined map ordering or struct enumeration.

# `scalar`

```elixir
@type scalar() :: nil | boolean() | integer() | float() | String.t()
```

JSON-safe scalar value after normalization

# `value`

```elixir
@type value() :: scalar() | [value()] | %{required(String.t()) =&gt; value()}
```

Normalized JSON value with string-keyed objects only

# `encode`

```elixir
@spec encode(term()) :: {:ok, String.t()} | {:error, Exception.t()}
```

# `encode!`

```elixir
@spec encode!(term()) :: String.t()
```

# `encoder_module`

```elixir
@spec encoder_module() :: module()
```

# `normalize`

```elixir
@spec normalize(term()) :: {:ok, value()} | {:error, Exception.t()}
```

# `normalize!`

```elixir
@spec normalize!(term()) :: value()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
