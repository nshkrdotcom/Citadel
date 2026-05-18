defmodule Citadel.ObservabilityContract.OperationalRunbook do
  @moduledoc """
  Runbook entry catalogue for operator-facing Phase 8 signals.
  """

  @signal_entry_names [
    :binding_lookup,
    :authority_decision,
    :credential_lease_materialization,
    :lower_invocation,
    :receipt_reduction,
    :projection_lag,
    :aitrace_export_lag,
    :live_provider_effect_status
  ]

  @slo_entry_names [
    :revocation_bound_ms,
    :tenant_bypass_attempts,
    :trace_export_drops,
    :external_secret_resolver_failures,
    :binding_cache_stale_reads,
    :projection_lag_ms,
    :lower_provider_error_rate
  ]

  @entry_names @signal_entry_names ++ @slo_entry_names

  @spec entry_names() :: [atom(), ...]
  def entry_names, do: @entry_names

  @spec signal_entry_names() :: [atom(), ...]
  def signal_entry_names, do: @signal_entry_names

  @spec slo_entry_names() :: [atom(), ...]
  def slo_entry_names, do: @slo_entry_names

  @spec entries() :: %{required(atom()) => map()}
  def entries, do: Map.new(@entry_names, &{&1, entry!(&1)})

  @spec entry!(atom()) :: map()
  def entry!(:binding_lookup) do
    entry(
      :binding_lookup,
      "Binding lookup health is degraded, stale, or outside the expected cache bound.",
      ["mix test test/citadel/observability_contract/operational_signal_test.exs"],
      ["binding lookup signal", "active binding cache age", "fail-closed stale action"],
      "mezzanine-config-registry-triage"
    )
  end

  def entry!(:authority_decision) do
    entry(
      :authority_decision,
      "Authority decision health is degraded or rejecting expected governed operations.",
      ["mix test test/citadel/observability_contract/operational_signal_test.exs"],
      ["authority decision signal", "tenant-scoped decision metadata", "safe action"],
      "citadel-runtime-triage"
    )
  end

  def entry!(:credential_lease_materialization) do
    entry(
      :credential_lease_materialization,
      "Credential lease materialization is degraded at the resolver or lease boundary.",
      ["mix test test/citadel/observability_contract/operational_signal_test.exs"],
      ["credential lease signal", "redacted credential handle ref", "no raw secret fields"],
      "jido-auth-triage"
    )
  end

  def entry!(:lower_invocation) do
    entry(
      :lower_invocation,
      "Lower invocation health is degraded or returning provider errors.",
      [
        "mix test test/citadel/observability_contract/operational_signal_test.exs",
        "~/scripts/with_bash_secrets mix extravaganza.headless.live.smoke"
      ],
      ["lower invocation signal", "binding descriptor dispatch evidence", "receipt status"],
      "mezzanine-integration-triage"
    )
  end

  def entry!(:receipt_reduction) do
    entry(
      :receipt_reduction,
      "Receipt reduction is degraded or unable to derive operator disposition.",
      ["mix test test/citadel/observability_contract/operational_signal_test.exs"],
      ["receipt reduction signal", "lineage-derived disposition", "no raw result payload"],
      "mezzanine-evidence-triage"
    )
  end

  def entry!(:projection_lag) do
    entry(
      :projection_lag,
      "Operator projections are lagging or reporting stale visible state.",
      ["mix test test/citadel/observability_contract/operational_signal_test.exs"],
      ["projection lag signal", "queue depth", "operator stale-projection status"],
      "app-kit-projection-triage"
    )
  end

  def entry!(:aitrace_export_lag) do
    entry(
      :aitrace_export_lag,
      "AITrace export lag is visible to operators without using AITrace as health transport.",
      [
        "mix test test/citadel/observability_contract/operational_signal_test.exs",
        "MIX_ENV=test mix test --only tenant_replay"
      ],
      ["AITrace export lag signal", "drop counter stays zero", "AITrace replay tests pass"],
      "aitrace-runtime-triage"
    )
  end

  def entry!(:revocation_bound_ms) do
    entry(
      :revocation_bound_ms,
      "Authority revocation visibility is outside the configured bound.",
      ["mix test test/citadel/observability_contract/operational_signal_test.exs"],
      ["citadel.operational.authority.revocation_bound_ms", "authority rejection evidence"],
      "citadel-runtime-triage"
    )
  end

  def entry!(:tenant_bypass_attempts) do
    entry(
      :tenant_bypass_attempts,
      "A cross-tenant authority or credential path attempted to bypass tenant scope.",
      ["mix test test/citadel/observability_contract/operational_signal_test.exs"],
      ["tenant bypass metric is zero", "P0 authority rejection log without raw payload"],
      "citadel-security-page"
    )
  end

  def entry!(:trace_export_drops) do
    entry(
      :trace_export_drops,
      "Trace export lag or drop counters indicate operator evidence may be incomplete.",
      [
        "mix test test/citadel/observability_contract/operational_signal_test.exs",
        "MIX_ENV=test mix test --only tenant_replay"
      ],
      ["AITrace export lag signal", "drop counter stays zero", "AITrace replay tests pass"],
      "aitrace-runtime-triage"
    )
  end

  def entry!(:external_secret_resolver_failures) do
    entry(
      :external_secret_resolver_failures,
      "Credential lease materialization failed at the external resolver boundary.",
      ["mix test test/citadel/observability_contract/operational_signal_test.exs"],
      ["credential lease signal", "redacted credential handle ref", "no raw secret fields"],
      "jido-auth-triage"
    )
  end

  def entry!(:binding_cache_stale_reads) do
    entry(
      :binding_cache_stale_reads,
      "Binding cache served or attempted to serve a stale epoch.",
      ["mix test test/citadel/observability_contract/operational_signal_test.exs"],
      ["binding lookup cache age", "stale read counter is zero", "fail-closed action"],
      "mezzanine-config-registry-triage"
    )
  end

  def entry!(:projection_lag_ms) do
    entry(
      :projection_lag_ms,
      "Operator projections are stale beyond the configured lag threshold.",
      ["mix test test/citadel/observability_contract/operational_signal_test.exs"],
      ["projection lag metric", "operator stale-projection status"],
      "app-kit-projection-triage"
    )
  end

  def entry!(:lower_provider_error_rate) do
    entry(
      :lower_provider_error_rate,
      "Lower provider effects are returning errors above the platform threshold.",
      [
        "mix test test/citadel/observability_contract/operational_signal_test.exs",
        "~/scripts/with_bash_secrets mix extravaganza.headless.live.smoke"
      ],
      ["lower invocation signal", "live provider effect status", "receipt reduction status"],
      "mezzanine-integration-triage"
    )
  end

  def entry!(:live_provider_effect_status) do
    entry(
      :live_provider_effect_status,
      "Live provider effect status is unhealthy for a product command.",
      ["~/scripts/with_bash_secrets mix extravaganza.headless.live.smoke"],
      ["live provider effect status", "operator-visible health without AITrace replay"],
      "extravaganza-operator-triage"
    )
  end

  def entry!(name) do
    raise ArgumentError, "unknown operational runbook entry #{inspect(name)}"
  end

  defp entry(name, symptom, commands, expected_evidence, escalation) do
    %{
      name: name,
      symptom: symptom,
      commands: commands,
      expected_evidence: expected_evidence,
      escalation: escalation,
      safe_action: "prefer-fail-closed-or-operator-visible-degraded-state"
    }
  end
end
