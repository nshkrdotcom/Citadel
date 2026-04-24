defmodule Citadel.GovernanceSubstrateIngressTest do
  use ExUnit.Case, async: true

  alias Citadel.ActionOutboxEntry
  alias Citadel.AuthorityContract.AuthorityDecision.V1, as: AuthorityDecisionV1
  alias Citadel.ExecutionGovernance.V1, as: ExecutionGovernanceV1
  alias Citadel.Governance.SubstrateIngress
  alias Citadel.InvocationRequest
  alias Citadel.InvocationRequest.V2, as: InvocationRequestV2

  @invocation_fixture_dir Path.expand("../fixtures/invocation_request", __DIR__)

  test "compiles an accepted substrate packet without host session continuity" do
    assert {:ok, compiled} =
             SubstrateIngress.compile(valid_packet("req-substrate"), [policy_pack()])

    assert %AuthorityDecisionV1{} = compiled.authority_packet
    assert compiled.decision_hash == compiled.authority_packet.decision_hash
    assert %InvocationRequestV2{} = compiled.lower_intent.invocation_request
    assert %ActionOutboxEntry{} = compiled.lower_intent.outbox_entry

    assert %ExecutionGovernanceV1{} =
             compiled.lower_intent.invocation_request.execution_governance

    request = compiled.lower_intent.invocation_request

    assert request.schema_version == InvocationRequestV2.schema_version()
    assert request.request_id == "execution-1"
    assert request.session_id == "substrate/execution-1"
    assert request.trace_id == "trace-substrate"

    assert request.extensions["citadel"]["ingress_provenance"]["ingress_kind"] ==
             "substrate_origin"

    refute get_in(request.extensions, ["citadel", "ingress_provenance", "host_request_id"])

    assert compiled.lower_intent.outbox_entry.action.action_kind ==
             "citadel.substrate_invocation_request.v2"

    assert compiled.lower_intent.outbox_entry.action.payload["contract"] ==
             "citadel.invocation_request.v2"

    assert compiled.lower_intent.outbox_entry.action.payload["invocation_request"][
             "schema_version"
           ] == InvocationRequestV2.schema_version()

    assert compiled.audit_attrs == %{
             decision_hash: compiled.decision_hash,
             execution_id: "execution-1",
             fact_kind: :substrate_governance_accepted,
             installation_id: "installation-1",
             subject_id: "subject-1",
             tenant_id: "tenant-1",
             trace_id: "trace-substrate"
           }
  end

  test "rejects legacy invocation request shaped input before action outbox" do
    legacy_request =
      "structured_request.json"
      |> read_invocation_fixture!()
      |> InvocationRequest.new!()
      |> InvocationRequest.dump()

    assert {:error, rejection} =
             SubstrateIngress.compile(legacy_request, [policy_pack()])

    assert rejection.class == :validation_error
    assert rejection.terminal?
    assert rejection.audit_attrs.fact_kind == :substrate_governance_validation_failed
    refute Map.has_key?(rejection, :lower_intent)
  end

  test "classifies unplannable substrate packets with non-terminal retry metadata" do
    packet =
      "req-rejected"
      |> valid_packet()
      |> put_in([:intent_envelope, :constraints, :boundary_requirement], :reuse_existing)
      |> put_in(
        [:intent_envelope, :target_hints, Access.at(0), :session_mode_preference],
        :detached
      )

    assert {:error, rejection} = SubstrateIngress.compile(packet, [policy_pack()])

    assert rejection.class == :policy_error
    assert rejection.terminal? == false
    assert rejection.operator_message == "boundary_reuse_requires_attached_session"
    assert rejection.audit_attrs.fact_kind == :substrate_governance_rejected
    assert rejection.audit_attrs.retryability == :after_input_change
    assert rejection.audit_attrs.publication_requirement == :host_only

    assert rejection.rejection_classification == %{
             rejection_id: "rejection/execution-1/boundary_reuse_requires_attached_session",
             stage: :planning,
             reason_code: "boundary_reuse_requires_attached_session",
             summary: "boundary_reuse_requires_attached_session",
             retryability: :after_input_change,
             publication_requirement: :host_only,
             extensions: %{
               "execution_id" => "execution-1",
               "trace_id" => "trace-substrate",
               "ingress_kind" => "substrate_origin"
             }
           }
  end

  test "maps plannable-packet assembly failures to readable operator messages" do
    packet =
      valid_packet("req-missing-intent")
      |> pop_in([
        :intent_envelope,
        :plan_hints,
        :candidate_steps,
        Access.at(0),
        :extensions,
        "citadel",
        "execution_intent"
      ])
      |> elem(1)

    assert {:error, rejection} = SubstrateIngress.compile(packet, [policy_pack()])

    assert rejection.operator_message == "candidate step is missing execution intent details"
    assert rejection.terminal? == false
    assert rejection.rejection_classification.retryability == :after_input_change
  end

  defp valid_packet(request_id) do
    %{
      tenant_id: "tenant-1",
      installation_id: "installation-1",
      installation_revision: 7,
      actor_ref: "scheduler",
      subject_id: "subject-1",
      execution_id: "execution-1",
      decision_id: "decision-1",
      request_trace_id: "request-trace",
      substrate_trace_id: "trace-substrate",
      idempotency_key: "tenant-1:subject-1:compile.workspace:7",
      capability_refs: ["compile.workspace"],
      policy_refs: ["policy-v1"],
      run_intent: %{"intent_id" => request_id, "capability" => "compile.workspace"},
      placement_constraints: %{"placement_ref" => "workspace_runtime"},
      risk_hints: ["writes_workspace"],
      metadata: %{"source" => "test"},
      intent_envelope: valid_intent_envelope(request_id)
    }
  end

  defp valid_intent_envelope(request_id) do
    %{
      intent_envelope_id: "intent/#{request_id}",
      scope_selectors: [
        %{
          scope_kind: "workspace",
          scope_id: "workspace/main",
          workspace_root: "/workspace/main",
          environment: "dev",
          preference: :required,
          extensions: %{}
        }
      ],
      desired_outcome: %{
        outcome_kind: :invoke_capability,
        requested_capabilities: ["compile.workspace"],
        result_kind: "workspace_patch",
        subject_selectors: ["primary"],
        extensions: %{}
      },
      constraints: %{
        boundary_requirement: :fresh_or_reuse,
        allowed_boundary_classes: ["workspace_session"],
        allowed_service_ids: ["svc.compiler"],
        forbidden_service_ids: [],
        max_steps: 1,
        review_required: false,
        extensions: %{}
      },
      risk_hints: [
        %{
          risk_code: "writes_workspace",
          severity: :medium,
          requires_governance: false,
          extensions: %{}
        }
      ],
      success_criteria: [
        %{
          criterion_kind: :completion,
          metric: "workspace_patch_applied",
          target: %{"status" => "accepted"},
          required: true,
          extensions: %{}
        }
      ],
      target_hints: [
        %{
          target_kind: "workspace",
          preferred_target_id: "workspace/main",
          preferred_service_id: "svc.compiler",
          preferred_boundary_class: "workspace_session",
          session_mode_preference: :attached,
          coordination_mode_preference: :single_target,
          routing_tags: ["primary"],
          extensions: %{}
        }
      ],
      plan_hints: %{
        candidate_steps: [
          %{
            step_kind: "capability",
            capability_id: "compile.workspace",
            allowed_operations: ["shell.exec"],
            extensions: %{
              "citadel" => %{
                "execution_intent_family" => "process",
                "execution_intent" => %{
                  "contract_version" => "v1",
                  "command" => "echo",
                  "args" => ["compile"],
                  "working_directory" => "/workspace/main",
                  "environment" => %{},
                  "stdin" => nil,
                  "extensions" => %{}
                },
                "allowed_tools" => ["bash", "git"],
                "effect_classes" => ["filesystem", "process"],
                "workspace_mutability" => "read_write",
                "placement_intent" => "remote_workspace",
                "downstream_scope" => "process:workspace",
                "execution_envelope" => %{
                  "submission_dedupe_key" => "tenant-1:subject-1:compile.workspace:7"
                }
              }
            }
          }
        ],
        preferred_targets: [],
        preferred_topology: nil,
        budget_hints: nil,
        extensions: %{}
      },
      resolution_provenance: %{
        source_kind: "test",
        resolver_kind: nil,
        resolver_version: nil,
        prompt_version: nil,
        policy_version: nil,
        confidence: 1.0,
        ambiguity_flags: [],
        raw_input_refs: [],
        raw_input_hashes: [],
        extensions: %{}
      },
      extensions: %{"citadel" => %{}}
    }
  end

  defp policy_pack do
    %{
      pack_id: "default",
      policy_version: "policy-v1",
      policy_epoch: 7,
      priority: 0,
      selector: %{
        tenant_ids: [],
        scope_kinds: [],
        environments: [],
        default?: true,
        extensions: %{}
      },
      profiles: %{
        trust_profile: "baseline",
        approval_profile: "standard",
        egress_profile: "restricted",
        workspace_profile: "workspace",
        resource_profile: "standard",
        boundary_class: "workspace_session",
        extensions: %{}
      },
      rejection_policy: %{
        denial_audit_reason_codes: ["policy_denied", "approval_missing"],
        derived_state_reason_codes: ["planning_failed"],
        runtime_change_reason_codes: ["scope_unavailable", "service_hidden", "boundary_stale"],
        governance_change_reason_codes: ["approval_missing"],
        extensions: %{}
      },
      extensions: %{}
    }
  end

  defp read_invocation_fixture!(name) do
    @invocation_fixture_dir
    |> Path.join(name)
    |> File.read!()
    |> Jason.decode!()
  end
end
