defmodule Citadel.PureCoreAdversarialTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import StreamData

  alias Citadel.ActionOutboxEntry
  alias Citadel.DecisionRejection
  alias Citadel.DecisionRejectionClassifier
  alias Citadel.DecisionSnapshot
  alias Citadel.IntentEnvelope
  alias Citadel.IntentMappingConstraints
  alias Citadel.KernelContext
  alias Citadel.SessionOutbox

  property "intent envelope adversarial variants never escape as generic crashes" do
    check all(candidate <- intent_envelope_candidate()) do
      assert_packet_safe(fn -> IntentEnvelope.new!(candidate) end, &match?(%IntentEnvelope{}, &1))

      assert_packet_safe(
        fn -> IntentMappingConstraints.boundary_mapping(candidate) end,
        &valid_boundary_mapping?/1
      )

      assert_packet_safe(
        fn -> IntentMappingConstraints.topology_mapping(candidate) end,
        &valid_topology_mapping?/1
      )

      assert_packet_safe(
        fn -> IntentMappingConstraints.planning_status(candidate) end,
        &valid_planning_status?/1
      )
    end
  end

  property "decision snapshot adversarial variants round trip or fail explicitly" do
    check all(candidate <- decision_snapshot_candidate()) do
      assert_packet_safe(fn -> DecisionSnapshot.new!(candidate) end, fn
        %DecisionSnapshot{} = snapshot ->
          snapshot == DecisionSnapshot.new!(DecisionSnapshot.dump(snapshot))

        _ ->
          false
      end)
    end
  end

  property "kernel context adversarial variants round trip or fail explicitly" do
    check all(candidate <- kernel_context_candidate()) do
      assert_packet_safe(fn -> KernelContext.new!(candidate) end, fn
        %KernelContext{} = context ->
          context == KernelContext.new!(KernelContext.dump(context))

        _ ->
          false
      end)
    end
  end

  property "action outbox entry adversarial variants preserve packet invariants or fail explicitly" do
    check all(candidate <- action_outbox_entry_candidate()) do
      assert_packet_safe(fn -> ActionOutboxEntry.new!(candidate) end, fn
        %ActionOutboxEntry{} = entry ->
          is_boolean(ActionOutboxEntry.replayable?(entry)) and
            SessionOutbox.invariant?(SessionOutbox.from_entries!([entry]))

        _ ->
          false
      end)
    end
  end

  property "rejection classification adversarial variants return DecisionRejection or explicit validation failure" do
    check all(
            rejection_attrs <- rejection_input_candidate(),
            rejection_policy <- rejection_policy_candidate()
          ) do
      assert_packet_safe(
        fn -> DecisionRejectionClassifier.classify!(rejection_attrs, rejection_policy) end,
        &match?(%DecisionRejection{}, &1)
      )
    end
  end

  defp assert_packet_safe(fun, success?) do
    case safe_call(fun) do
      {:ok, value} ->
        assert success?.(value)

      {:error, %ArgumentError{}} ->
        :ok

      {:error, error} ->
        flunk("unexpected generic crash: #{inspect(error.__struct__)} #{Exception.message(error)}")
    end
  end

  defp safe_call(fun) do
    {:ok, fun.()}
  rescue
    error -> {:error, error}
  end

  defp valid_boundary_mapping?(%{
         requested_attach_mode: mode,
         preferred_boundary_class: preferred_boundary_class,
         allowed_boundary_classes: allowed_boundary_classes
       }) do
    mode in IntentMappingConstraints.allowed_attach_modes() and
      is_list(allowed_boundary_classes) and
      (is_nil(preferred_boundary_class) or is_binary(preferred_boundary_class))
  end

  defp valid_boundary_mapping?(_), do: false

  defp valid_topology_mapping?(%{
         session_mode: session_mode,
         coordination_mode: coordination_mode,
         routing_hints: %{
           preferred_target_ids: preferred_target_ids,
           preferred_service_ids: preferred_service_ids,
           routing_tags: routing_tags
         }
       }) do
    session_mode in IntentMappingConstraints.allowed_session_modes() and
      coordination_mode in IntentMappingConstraints.allowed_coordination_modes() and
      is_list(preferred_target_ids) and
      is_list(preferred_service_ids) and
      is_list(routing_tags)
  end

  defp valid_topology_mapping?(_), do: false

  defp valid_planning_status?(:plannable), do: true
  defp valid_planning_status?({:unplannable, reason}) when is_binary(reason), do: true
  defp valid_planning_status?(_), do: false

  defp intent_envelope_candidate do
    one_of([
      valid_intent_envelope_attrs(),
      map(valid_intent_envelope_attrs(), &put_in(&1, [:constraints, :boundary_requirement], :reuse_existing)),
      map(valid_intent_envelope_attrs(), &Map.put(&1, :target_hints, [detached_target_hint_attrs()])),
      map(valid_intent_envelope_attrs(), &put_in(&1, [:desired_outcome, :outcome_kind], :inspect_scope)),
      map(valid_intent_envelope_attrs(), &put_in(&1, [:constraints, :boundary_requirement], :fresh_only)),
      map(valid_intent_envelope_attrs(), &Map.put(&1, :scope_selectors, [])),
      map(valid_intent_envelope_attrs(), &put_in(&1, [:desired_outcome, :requested_capabilities], [])),
      map(valid_intent_envelope_attrs(), &put_in(&1, [:constraints, :max_steps], 0)),
      map(valid_intent_envelope_attrs(), &Map.put(&1, :success_criteria, [])),
      map(valid_intent_envelope_attrs(), &put_in(&1, [:constraints, :allowed_service_ids], ["svc-terminal", "svc-terminal"])),
      map(valid_intent_envelope_attrs(), &put_in(&1, [:extensions], %{"bad" => {:tuple, 1}})),
      map(valid_intent_envelope_attrs(), &Map.put(&1, :intent, "open the repo"))
    ])
  end

  defp decision_snapshot_candidate do
    one_of([
      valid_decision_snapshot_attrs(),
      map(valid_decision_snapshot_attrs(), &Map.put(&1, :policy_version, "   ")),
      map(valid_decision_snapshot_attrs(), &Map.put(&1, :policy_epoch, -1)),
      map(valid_decision_snapshot_attrs(), &Map.put(&1, :captured_at, "not-a-datetime")),
      map(valid_decision_snapshot_attrs(), &put_in(&1, [:extensions], %{"nested" => %{"epoch" => [1, 2, 3]}})),
      map(valid_decision_snapshot_attrs(), &put_in(&1, [:extensions], %{"bad" => {:tuple, 1}}))
    ])
  end

  defp kernel_context_candidate do
    one_of([
      valid_kernel_context_attrs(),
      map(valid_kernel_context_attrs(), &Map.put(&1, :trace_id, "   ")),
      map(valid_kernel_context_attrs(), &Map.put(&1, :policy_epoch, -1)),
      map(valid_kernel_context_attrs(), &Map.put(&1, :scope_ref, %{scope_kind: "project"})),
      map(valid_kernel_context_attrs(), &Map.put(&1, :decision_snapshot, %{policy_epoch: -1})),
      map(valid_kernel_context_attrs(), &Map.put(&1, :selected_service, %{service_id: 7})),
      map(valid_kernel_context_attrs(), &Map.put(&1, :external_refs, %{"bad" => {:tuple, 1}}))
    ])
  end

  defp action_outbox_entry_candidate do
    one_of([
      valid_action_outbox_entry_attrs(),
      map(valid_action_outbox_entry_attrs(), &Map.put(&1, :staleness_requirements, nil)),
      map(valid_action_outbox_entry_attrs(), fn attrs ->
        attrs
        |> Map.put(:staleness_mode, :stale_exempt)
        |> Map.put(:staleness_requirements, valid_staleness_requirements_map())
      end),
      map(valid_action_outbox_entry_attrs(), &Map.put(&1, :replay_status, :completed)),
      map(valid_action_outbox_entry_attrs(), fn attrs ->
        attrs
        |> Map.put(:replay_status, :dead_letter)
        |> Map.put(:dead_letter_reason, nil)
      end),
      map(valid_action_outbox_entry_attrs(), fn attrs ->
        attrs
        |> Map.put(:attempt_count, 6)
        |> Map.put(:max_attempts, 5)
      end),
      map(valid_action_outbox_entry_attrs(), fn attrs ->
        put_in(attrs, [:backoff_policy, :linear_step_ms], nil)
      end),
      map(valid_action_outbox_entry_attrs(), &put_in(&1, [:action, :payload], %{"bad" => {:tuple, 1}})),
      map(valid_action_outbox_entry_attrs(), &put_in(&1, [:extensions], %{"nested" => %{"attempt" => 1}}))
    ])
  end

  defp rejection_input_candidate do
    one_of([
      valid_rejection_input_attrs(),
      map(valid_rejection_input_attrs(), &Map.put(&1, :causes, :runtime_state)),
      map(valid_rejection_input_attrs(), &Map.put(&1, :causes, [:runtime_state, :bogus])),
      map(valid_rejection_input_attrs(), &Map.put(&1, :stage, :unsupported_stage)),
      map(valid_rejection_input_attrs(), &Map.put(&1, :summary, "   "))
    ])
  end

  defp rejection_policy_candidate do
    one_of([
      valid_rejection_policy_attrs(),
      map(valid_rejection_policy_attrs(), &put_in(&1, [:runtime_change_reason_codes], ["scope_unavailable", "scope_unavailable"])),
      map(valid_rejection_policy_attrs(), &put_in(&1, [:extensions], %{"bad" => {:tuple, 1}}))
    ])
  end

  defp valid_intent_envelope_attrs do
    gen all(
          intent_envelope_id <- identifier("intent"),
          scope_id <- identifier("scope"),
          requested_capabilities <- uniq_list_of(identifier("cap"), min_length: 1, max_length: 3),
          max_steps <- integer(1..5),
          review_required <- boolean(),
          routing_tags <- uniq_list_of(identifier("tag"), max_length: 3),
          plan_step_capability <- identifier("cap"),
          include_plan_hints? <- boolean(),
          include_provenance? <- boolean(),
          confidence <- confidence(),
          extensions <- json_object(1)
        ) do
      %{
        intent_envelope_id: intent_envelope_id,
        scope_selectors: [
          %{
            scope_kind: "project",
            scope_id: scope_id,
            workspace_root: "/workspace/#{scope_id}",
            environment: "prod",
            preference: :required,
            extensions: %{"selectors" => ["repo_local"]}
          }
        ],
        desired_outcome: %{
          outcome_kind: :invoke_capability,
          requested_capabilities: requested_capabilities,
          result_kind: "invocation",
          subject_selectors: ["workspace"],
          extensions: %{}
        },
        constraints: %{
          boundary_requirement: :fresh_or_reuse,
          allowed_boundary_classes: ["workspace_session"],
          allowed_service_ids: ["svc-terminal"],
          forbidden_service_ids: [],
          max_steps: max_steps,
          review_required: review_required,
          extensions: %{"limits" => %{"max_steps" => max_steps}}
        },
        risk_hints: [
          %{
            risk_code: "repo_mutation",
            severity: :high,
            requires_governance: true,
            extensions: %{}
          }
        ],
        success_criteria: [
          %{
            criterion_kind: :completion,
            metric: "status",
            target: %{"state" => "done"},
            required: true,
            extensions: %{}
          }
        ],
        target_hints: [
          %{
            target_kind: "workspace",
            preferred_target_id: "target-shell-1",
            preferred_service_id: "svc-terminal",
            preferred_boundary_class: "workspace_session",
            session_mode_preference: :attached,
            coordination_mode_preference: :single_target,
            routing_tags: routing_tags,
            extensions: %{}
          }
        ],
        plan_hints:
          if(include_plan_hints?,
            do: %{
              candidate_steps: [
                %{
                  step_kind: "workspace_mutation",
                  capability_id: plan_step_capability,
                  allowed_operations: ["read", "write"],
                  extensions: %{}
                }
              ],
              preferred_targets: [],
              preferred_topology: nil,
              budget_hints: %{
                max_steps: max_steps,
                max_runtime_ms: 60_000,
                max_reviews: if(review_required, do: 1, else: 0),
                extensions: %{}
              },
              extensions: %{}
            },
            else: nil
          ),
        resolution_provenance:
          if(include_provenance?,
            do: %{
              source_kind: "host_surface_harness",
              resolver_kind: "stub",
              resolver_version: "2026-04-10",
              prompt_version: "v1",
              policy_version: "policy-2026-04-10",
              confidence: confidence,
              ambiguity_flags: ["none"],
              raw_input_refs: ["raw-ref-1"],
              raw_input_hashes: ["sha256:abc123"],
              extensions: %{}
            },
            else: nil
          ),
        extensions: %{"citadel" => extensions}
      }
    end
  end

  defp detached_target_hint_attrs do
    %{
      target_kind: "workspace",
      preferred_target_id: "target-shell-detached",
      preferred_service_id: "svc-terminal",
      preferred_boundary_class: "workspace_session",
      session_mode_preference: :detached,
      coordination_mode_preference: :single_target,
      routing_tags: ["repo_local"],
      extensions: %{}
    }
  end

  defp valid_decision_snapshot_attrs do
    gen all(
          snapshot_seq <- integer(0..50),
          captured_at <- datetime_value(),
          policy_version <- identifier("policy"),
          policy_epoch <- integer(0..10),
          topology_epoch <- integer(0..10),
          scope_catalog_epoch <- integer(0..10),
          service_admission_epoch <- integer(0..10),
          project_binding_epoch <- integer(0..10),
          boundary_epoch <- integer(0..10),
          extensions <- json_object(1)
        ) do
      %{
        snapshot_seq: snapshot_seq,
        captured_at: captured_at,
        policy_version: policy_version,
        policy_epoch: policy_epoch,
        topology_epoch: topology_epoch,
        scope_catalog_epoch: scope_catalog_epoch,
        service_admission_epoch: service_admission_epoch,
        project_binding_epoch: project_binding_epoch,
        boundary_epoch: boundary_epoch,
        extensions: extensions
      }
    end
  end

  defp valid_kernel_context_attrs do
    gen all(
          request_id <- identifier("request"),
          tenant_id <- identifier("tenant"),
          trace_id <- identifier("trace"),
          actor_id <- identifier("actor"),
          session_id <- identifier("session"),
          policy_version <- identifier("policy"),
          policy_epoch <- integer(0..10),
          topology_epoch <- integer(0..10),
          scope_id <- identifier("scope"),
          decision_snapshot <- optional(valid_decision_snapshot_attrs()),
          external_refs <- json_object(1)
        ) do
      %{
        request_id: request_id,
        tenant_id: tenant_id,
        trace_id: trace_id,
        actor_id: actor_id,
        session_id: session_id,
        scope_ref: %{
          scope_id: scope_id,
          scope_kind: "project",
          workspace_root: "/workspace/#{scope_id}",
          environment: "prod",
          catalog_epoch: 7,
          extensions: %{}
        },
        policy_version: policy_version,
        policy_epoch: policy_epoch,
        topology_epoch: topology_epoch,
        trust_profile: "trusted_operator",
        approval_profile: "approval_required",
        egress_profile: "restricted",
        workspace_profile: "project_workspace",
        resource_profile: "standard",
        boundary_class: "workspace_session",
        decision_snapshot: decision_snapshot,
        project_binding: %{
          binding_id: "binding-#{session_id}",
          session_id: session_id,
          project_id: "project-#{tenant_id}",
          workspace_root: "/workspace/#{scope_id}",
          binding_epoch: 3,
          extensions: %{}
        },
        selected_target: %{
          target_id: "target-shell-1",
          target_kind: "workspace",
          target_capabilities: ["shell"],
          boundary_capabilities: ["workspace_session"],
          selection_reason: "preferred_target",
          catalog_epoch: 7,
          extensions: %{}
        },
        selected_service: %{
          service_id: "svc-terminal",
          service_kind: "terminal",
          capabilities: ["shell"],
          visibility: "visible",
          admission_epoch: 5,
          extensions: %{}
        },
        existing_boundary_ref: "boundary-ref-1",
        signal_cursor: "signal-cursor-1",
        external_refs: external_refs,
        extensions: %{"citadel" => %{"stage" => "adversarial"}}
      }
    end
  end

  defp valid_action_outbox_entry_attrs do
    gen all(
          entry_id <- identifier("entry"),
          group_id <- identifier("group"),
          inserted_at <- datetime_value()
        ) do
      %{
        schema_version: 1,
        entry_id: entry_id,
        causal_group_id: group_id,
        action: %{
          action_kind: "submit_invocation",
          payload: %{"entry_id" => entry_id},
          extensions: %{}
        },
        inserted_at: inserted_at,
        replay_status: :pending,
        durable_receipt_ref: nil,
        attempt_count: 0,
        max_attempts: 5,
        backoff_policy: %{
          strategy: :linear,
          base_delay_ms: 100,
          max_delay_ms: 1_000,
          linear_step_ms: 50,
          multiplier: nil,
          jitter_mode: :entry_stable,
          jitter_window_ms: 25,
          extensions: %{}
        },
        next_attempt_at: nil,
        last_error_code: nil,
        dead_letter_reason: nil,
        ordering_mode: :strict,
        staleness_mode: :requires_check,
        staleness_requirements: valid_staleness_requirements_map(),
        extensions: %{}
      }
    end
  end

  defp valid_staleness_requirements_map do
    %{
      snapshot_seq: 10,
      policy_epoch: 3,
      topology_epoch: nil,
      scope_catalog_epoch: nil,
      service_admission_epoch: nil,
      project_binding_epoch: nil,
      boundary_epoch: nil,
      required_binding_id: nil,
      required_boundary_ref: nil,
      extensions: %{}
    }
  end

  defp valid_rejection_input_attrs do
    gen all(
          rejection_id <- identifier("rejection"),
          stage <- member_of([:scope_resolution, :service_admission, :planning]),
          reason_code <- member_of(["policy_denied", "approval_missing", "scope_unavailable"]),
          summary <- identifier("summary"),
          causes <- uniq_list_of(member_of([:input, :runtime_state, :governance, :policy_denial]), max_length: 3),
          extensions <- json_object(1)
        ) do
      %{
        rejection_id: rejection_id,
        stage: stage,
        reason_code: reason_code,
        summary: summary,
        causes: causes,
        extensions: extensions
      }
    end
  end

  defp valid_rejection_policy_attrs do
    gen all(extensions <- json_object(1)) do
      %{
        denial_audit_reason_codes: ["policy_denied", "approval_missing"],
        derived_state_reason_codes: ["planning_failed"],
        runtime_change_reason_codes: ["scope_unavailable", "service_hidden", "boundary_stale"],
        governance_change_reason_codes: ["approval_missing"],
        extensions: extensions
      }
    end
  end

  defp identifier(prefix) do
    map(string(:alphanumeric, min_length: 1, max_length: 24), fn suffix ->
      "#{prefix}-#{suffix}"
    end)
  end

  defp confidence do
    map(integer(0..100), &(&1 / 100))
  end

  defp datetime_value do
    map(integer(0..3_600), &DateTime.add(~U[2026-04-10 00:00:00Z], &1, :second))
  end

  defp optional(generator) do
    one_of([constant(nil), generator])
  end

  defp json_object(depth) do
    map_of(json_key(), json_value(depth), max_length: 3)
  end

  defp json_value(0) do
    one_of([
      constant(nil),
      boolean(),
      integer(-10..10),
      map(integer(0..100), &(&1 / 10)),
      string(:alphanumeric, max_length: 16)
    ])
  end

  defp json_value(depth) do
    one_of([
      json_value(0),
      list_of(json_value(depth - 1), max_length: 3),
      json_object(depth - 1)
    ])
  end

  defp json_key do
    string(:alphanumeric, min_length: 1, max_length: 12)
  end
end
