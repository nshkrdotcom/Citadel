defmodule Citadel.ObservabilityContract.TelemetryCardinalityTest do
  use ExUnit.Case, async: true

  alias Citadel.ObservabilityContract
  alias Citadel.ObservabilityContract.CardinalityBounds
  alias Citadel.ObservabilityContract.Telemetry

  test "telemetry definitions expose explicit allowlisted metric labels" do
    metric_profile = CardinalityBounds.profile!(:metric)

    for {name, definition} <- Telemetry.definitions() do
      assert MapSet.subset?(MapSet.new(definition.metric_labels), MapSet.new(definition.metadata))
      assert length(definition.metric_labels) <= metric_profile.max_label_keys
      assert :ok = CardinalityBounds.validate_metric_labels(definition.metric_labels)
      assert Telemetry.metric_label_keys(name) == definition.metric_labels
      assert ObservabilityContract.telemetry_metric_label_keys(name) == definition.metric_labels
    end
  end

  test "trace publication correlation ids remain metadata but are not metric labels" do
    failure_labels = Telemetry.metric_label_keys(:trace_publication_failure)
    drop_labels = Telemetry.metric_label_keys(:trace_publication_drop)

    assert failure_labels == [:reason_code, :family]
    assert drop_labels == [:dropped_family, :dropped_family_classification]

    high_cardinality_keys = [
      :trace_id,
      :tenant_id,
      :request_id,
      :decision_id,
      :boundary_ref,
      :trace_envelope_id
    ]

    for key <- high_cardinality_keys do
      assert key in Telemetry.metadata_keys(:trace_publication_failure)
      assert key in Telemetry.metadata_keys(:trace_publication_drop)
      refute key in failure_labels
      refute key in drop_labels
    end
  end

  test "all telemetry metric labels stay disjoint from the high-cardinality blocklist" do
    blocked_labels = MapSet.new(CardinalityBounds.high_cardinality_metric_label_blocklist())

    for {name, definition} <- Telemetry.definitions() do
      assert MapSet.disjoint?(MapSet.new(definition.metric_labels), blocked_labels),
             "#{inspect(name)} exposes blocked metric labels #{inspect(definition.metric_labels)}"
    end
  end
end
