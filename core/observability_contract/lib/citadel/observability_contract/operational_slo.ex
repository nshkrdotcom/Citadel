defmodule Citadel.ObservabilityContract.OperationalSLO do
  @moduledoc """
  Operator-facing SLO and threshold catalogue for Phase 8 signals.
  """

  alias Citadel.ContractCore.AttrMap

  @contract_name "Platform.OperationalSLOThreshold.v1"
  @contract_version "1.0.0"
  @release_manifest_ref "phase8-operational-observability"

  @threshold_names [
    :revocation_bound_ms,
    :tenant_bypass_attempts,
    :trace_export_drops,
    :external_secret_resolver_failures,
    :binding_cache_stale_reads,
    :projection_lag_ms,
    :lower_provider_error_rate
  ]

  @severities [:p0, :p1, :p2, :p3]
  @operators [:less_than_or_equal, :equal_to, :ratio_less_than_or_equal]

  @fields [
    :contract_name,
    :contract_version,
    :threshold_name,
    :owner_repo,
    :owner_package,
    :metric_ref,
    :operator,
    :threshold,
    :window_ms,
    :severity,
    :runbook_ref,
    :safe_action,
    :release_manifest_ref
  ]

  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{}

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec threshold_names() :: [atom(), ...]
  def threshold_names, do: @threshold_names

  @spec thresholds() :: %{required(atom()) => t()}
  def thresholds, do: Map.new(@threshold_names, &{&1, threshold!(&1)})

  @spec threshold!(atom() | String.t() | map() | keyword()) :: t()
  def threshold!(name) when is_atom(name) or is_binary(name) do
    name
    |> default_attrs()
    |> new!()
  end

  def threshold!(attrs), do: new!(attrs)

  @spec new(t() | map() | keyword()) :: {:ok, t()} | {:error, Exception.t()}
  def new(%__MODULE__{} = threshold), do: normalize(threshold)

  def new(attrs) do
    {:ok, build!(attrs)}
  rescue
    error in ArgumentError -> {:error, error}
  end

  @spec new!(t() | map() | keyword()) :: t()
  def new!(%__MODULE__{} = threshold) do
    case normalize(threshold) do
      {:ok, normalized} -> normalized
      {:error, %ArgumentError{} = error} -> raise error
    end
  end

  def new!(attrs), do: build!(attrs)

  @spec validate_threshold(t() | map() | keyword()) :: :ok | {:error, Exception.t()}
  def validate_threshold(threshold) do
    case new(threshold) do
      {:ok, _threshold} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @spec dump(t()) :: map()
  def dump(%__MODULE__{} = threshold) do
    Map.new(@fields, &{&1, Map.fetch!(threshold, &1)})
  end

  defp default_attrs(:revocation_bound_ms) do
    base_attrs(:revocation_bound_ms, %{
      owner_repo: "citadel",
      owner_package: "core/citadel_kernel",
      metric_ref: "citadel.operational.authority.revocation_bound_ms",
      operator: :less_than_or_equal,
      threshold: 30_000,
      window_ms: 60_000,
      severity: :p1,
      safe_action: "reject-or-recheck-authority-after-revocation-bound"
    })
  end

  defp default_attrs(:tenant_bypass_attempts) do
    base_attrs(:tenant_bypass_attempts, %{
      owner_repo: "citadel",
      owner_package: "core/citadel_kernel",
      metric_ref: "citadel.operational.authority.tenant_bypass_attempts",
      operator: :equal_to,
      threshold: 0,
      window_ms: 60_000,
      severity: :p0,
      safe_action: "fail-closed-and-page-on-tenant-bypass-attempt"
    })
  end

  defp default_attrs(:trace_export_drops) do
    base_attrs(:trace_export_drops, %{
      owner_repo: "AITrace",
      owner_package: "core/replay_engine",
      metric_ref: "aitrace.operational.export.dropped_count",
      operator: :equal_to,
      threshold: 0,
      window_ms: 60_000,
      severity: :p1,
      safe_action: "route-export-drop-before-claiming-replay-completeness"
    })
  end

  defp default_attrs(:external_secret_resolver_failures) do
    base_attrs(:external_secret_resolver_failures, %{
      owner_repo: "jido_integration",
      owner_package: "core/auth",
      metric_ref: "jido.operational.external_secret_resolver.failure_rate",
      operator: :ratio_less_than_or_equal,
      threshold: 0.01,
      window_ms: 300_000,
      severity: :p1,
      safe_action: "fail-closed-without-credential-materialization"
    })
  end

  defp default_attrs(:binding_cache_stale_reads) do
    base_attrs(:binding_cache_stale_reads, %{
      owner_repo: "mezzanine",
      owner_package: "core/config_registry",
      metric_ref: "mezzanine.operational.binding_cache.stale_reads",
      operator: :equal_to,
      threshold: 0,
      window_ms: 60_000,
      severity: :p1,
      safe_action: "invalidate-cache-and-fail-closed-on-stale-epoch"
    })
  end

  defp default_attrs(:projection_lag_ms) do
    base_attrs(:projection_lag_ms, %{
      owner_repo: "app_kit",
      owner_package: "bridges/projection_bridge",
      metric_ref: "app_kit.operational.projection.lag_ms",
      operator: :less_than_or_equal,
      threshold: 5_000,
      window_ms: 60_000,
      severity: :p2,
      safe_action: "surface-stale-projection-to-operator"
    })
  end

  defp default_attrs(:lower_provider_error_rate) do
    base_attrs(:lower_provider_error_rate, %{
      owner_repo: "mezzanine",
      owner_package: "bridges/integration_bridge",
      metric_ref: "mezzanine.operational.lower_invocation.provider_error_rate",
      operator: :ratio_less_than_or_equal,
      threshold: 0.02,
      window_ms: 300_000,
      severity: :p1,
      safe_action: "route-live-provider-errors-without-generic-control-branches"
    })
  end

  defp default_attrs(name) do
    name = enum_atom!(name, :threshold_name, @threshold_names)
    default_attrs(name)
  end

  defp base_attrs(name, attrs) do
    Map.merge(
      %{
        contract_name: @contract_name,
        contract_version: @contract_version,
        threshold_name: name,
        runbook_ref: "docs/runbooks/operational_observability.md##{name}",
        release_manifest_ref: @release_manifest_ref
      },
      attrs
    )
  end

  defp build!(attrs) do
    attrs = AttrMap.normalize!(attrs, @contract_name)

    %__MODULE__{
      contract_name:
        attrs
        |> AttrMap.get(:contract_name, @contract_name)
        |> literal!(@contract_name, :contract_name),
      contract_version:
        attrs
        |> AttrMap.get(:contract_version, @contract_version)
        |> literal!(@contract_version, :contract_version),
      threshold_name:
        attrs
        |> AttrMap.fetch!(:threshold_name, @contract_name)
        |> enum_atom!(:threshold_name, @threshold_names),
      owner_repo: required_string!(attrs, :owner_repo),
      owner_package: required_string!(attrs, :owner_package),
      metric_ref: required_string!(attrs, :metric_ref),
      operator:
        attrs
        |> AttrMap.fetch!(:operator, @contract_name)
        |> enum_atom!(:operator, @operators),
      threshold: non_negative_number!(attrs, :threshold),
      window_ms: positive_integer!(attrs, :window_ms),
      severity:
        attrs
        |> AttrMap.fetch!(:severity, @contract_name)
        |> enum_atom!(:severity, @severities),
      runbook_ref: required_string!(attrs, :runbook_ref),
      safe_action: required_string!(attrs, :safe_action),
      release_manifest_ref: required_string!(attrs, :release_manifest_ref)
    }
  end

  defp normalize(%__MODULE__{} = threshold) do
    {:ok, threshold |> dump() |> build!()}
  rescue
    error in ArgumentError -> {:error, error}
  end

  defp required_string!(attrs, key) do
    attrs
    |> AttrMap.fetch!(key, @contract_name)
    |> string!(key)
  end

  defp string!(value, _key) when is_binary(value) do
    if String.trim(value) == "" do
      raise ArgumentError, "#{@contract_name} fields must be non-empty strings"
    end

    value
  end

  defp string!(value, key) do
    raise ArgumentError,
          "#{@contract_name}.#{key} must be a non-empty string, got #{inspect(value)}"
  end

  defp positive_integer!(attrs, key) do
    value = AttrMap.fetch!(attrs, key, @contract_name)

    if is_integer(value) and value > 0 do
      value
    else
      raise ArgumentError, "#{@contract_name}.#{key} must be a positive integer"
    end
  end

  defp non_negative_number!(attrs, key) do
    value = AttrMap.fetch!(attrs, key, @contract_name)

    cond do
      is_integer(value) and value >= 0 -> value
      is_float(value) and value >= 0.0 -> value
      true -> raise ArgumentError, "#{@contract_name}.#{key} must be non-negative"
    end
  end

  defp literal!(value, expected, _key) when value == expected, do: value

  defp literal!(value, expected, key) do
    raise ArgumentError, "#{@contract_name}.#{key} must be #{expected}, got #{inspect(value)}"
  end

  defp enum_atom!(value, key, allowed) when is_atom(value) do
    if value in allowed do
      value
    else
      raise ArgumentError,
            "#{@contract_name}.#{key} must be one of #{inspect(allowed)}, got #{inspect(value)}"
    end
  end

  defp enum_atom!(value, key, allowed) when is_binary(value) do
    Enum.find(allowed, &(Atom.to_string(&1) == value)) ||
      raise ArgumentError, "#{@contract_name}.#{key} must be one of #{inspect(allowed)}"
  end

  defp enum_atom!(value, key, allowed) do
    raise ArgumentError,
          "#{@contract_name}.#{key} must be one of #{inspect(allowed)}, got #{inspect(value)}"
  end
end
