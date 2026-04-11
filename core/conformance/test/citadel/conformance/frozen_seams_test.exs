defmodule Citadel.Conformance.FrozenSeamsTest do
  use ExUnit.Case, async: true

  alias Citadel.Apps.HostSurfaceHarness
  alias Citadel.AuthorityContract.AuthorityDecision.V1
  alias Citadel.BoundaryIntent
  alias Citadel.DecisionRejection
  alias Citadel.IntentEnvelope
  alias Citadel.IntentMappingConstraints
  alias Citadel.InvocationRequest
  alias Citadel.TopologyIntent

  test "guards the frozen invocation and ingress carrier inventories" do
    assert InvocationRequest.schema_version() == 1

    assert InvocationRequest.required_fields() == [
             :schema_version,
             :invocation_request_id,
             :request_id,
             :session_id,
             :tenant_id,
             :trace_id,
             :actor_id,
             :target_id,
             :target_kind,
             :selected_step_id,
             :allowed_operations,
             :authority_packet,
             :boundary_intent,
             :topology_intent,
             :extensions
           ]

    assert Keyword.keys(InvocationRequest.schema()) == InvocationRequest.required_fields()

    assert BoundaryIntent.required_fields() == [
             :boundary_class,
             :trust_profile,
             :workspace_profile,
             :resource_profile,
             :requested_attach_mode,
             :requested_ttl_ms,
             :extensions
           ]

    assert TopologyIntent.required_fields() == [
             :topology_intent_id,
             :session_mode,
             :routing_hints,
             :coordination_mode,
             :topology_epoch,
             :extensions
           ]

    assert Map.keys(IntentEnvelope.frozen_subschemas()) |> Enum.sort() == [
             :constraints,
             :desired_outcome,
             :plan_hints,
             :risk_hint,
             :scope_selector,
             :success_criterion,
             :target_hint
           ]

    assert IntentMappingConstraints.allowed_attach_modes() == [
             "reuse_existing",
             "fresh_or_reuse",
             "fresh_only",
             "not_applicable"
           ]

    assert IntentMappingConstraints.allowed_session_modes() == [:attached, :detached, :stateless]

    assert IntentMappingConstraints.allowed_coordination_modes() == [
             :single_target,
             :parallel_fanout,
             :local_only
           ]

    assert DecisionRejection.allowed_retryability() == [
             :terminal,
             :after_input_change,
             :after_runtime_change,
             :after_governance_change
           ]

    assert DecisionRejection.allowed_publication_requirements() == [
             :host_only,
             :review_projection,
             :derived_state_attachment
           ]
  end

  test "exercises valid and deliberately unplannable Wave 3 ingress cases through public constructors" do
    valid = HostSurfaceHarness.valid_direct_envelope()
    unplannable = HostSurfaceHarness.unplannable_direct_envelope()

    assert %IntentEnvelope{} = valid
    assert %IntentEnvelope{} = unplannable
    assert IntentMappingConstraints.planning_status(valid) == :plannable

    assert IntentMappingConstraints.planning_status(unplannable) ==
             {:unplannable, "boundary_reuse_requires_attached_session"}

    assert_raise ArgumentError, ~r/unsupported fields: \["intent"\]/, fn ->
      valid
      |> IntentEnvelope.dump()
      |> Map.put(:intent, "open the repo")
      |> IntentEnvelope.new!()
    end
  end

  test "fails immediately on unsupported InvocationRequest schema mutations" do
    assert %InvocationRequest{} = InvocationRequest.new!(invocation_request_attrs())

    assert_raise ArgumentError, ~r/schema_version must be 1/, fn ->
      invocation_request_attrs()
      |> Map.put(:schema_version, 2)
      |> InvocationRequest.new!()
    end
  end

  defp invocation_request_attrs do
    %{
      schema_version: 1,
      invocation_request_id: "invoke-1",
      request_id: "req-1",
      session_id: "sess-1",
      tenant_id: "tenant-1",
      trace_id: "trace-1",
      actor_id: "actor-1",
      target_id: "workspace/main",
      target_kind: "workspace",
      selected_step_id: "step-1",
      allowed_operations: ["write_patch"],
      authority_packet: authority_packet(),
      boundary_intent: %{
        boundary_class: "workspace_session",
        trust_profile: "baseline",
        workspace_profile: "workspace",
        resource_profile: "standard",
        requested_attach_mode: "fresh_or_reuse",
        requested_ttl_ms: 300_000,
        extensions: %{}
      },
      topology_intent: %{
        topology_intent_id: "topology-1",
        session_mode: "attached",
        routing_hints: %{"preferred_target_ids" => ["workspace/main"]},
        coordination_mode: "single_target",
        topology_epoch: 1,
        extensions: %{}
      },
      extensions: %{
        "citadel" => %{
          "ingress_provenance" => %{
            "raw_input_refs" => ["raw://intent/1"],
            "raw_input_hashes" => ["sha256:1234abcd"]
          }
        }
      }
    }
  end

  defp authority_packet do
    V1.new!(%{
      contract_version: "v1",
      decision_id: "decision-1",
      tenant_id: "tenant-1",
      request_id: "req-1",
      policy_version: "policy-2026-04-09",
      boundary_class: "workspace_session",
      trust_profile: "baseline",
      approval_profile: "standard",
      egress_profile: "restricted",
      workspace_profile: "workspace",
      resource_profile: "standard",
      decision_hash: String.duplicate("a", 64),
      extensions: %{"citadel" => %{}}
    })
  end
end
