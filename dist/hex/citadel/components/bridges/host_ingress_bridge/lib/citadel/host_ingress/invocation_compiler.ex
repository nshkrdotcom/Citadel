defmodule Citadel.HostIngress.InvocationCompiler do
  @moduledoc """
  Pure compiler from structured host ingress into durable Citadel invocation work.
  """

  alias Citadel.ActionOutboxEntry
  alias Citadel.AuthorityContract.AuthorityDecision.V1, as: AuthorityDecisionV1
  alias Citadel.BackoffPolicy
  alias Citadel.BoundaryIntent
  alias Citadel.DecisionHash
  alias Citadel.DecisionRejection
  alias Citadel.DecisionRejectionClassifier
  alias Citadel.ExecutionGovernanceCompiler
  alias Citadel.HostIngress.InvocationPayload
  alias Citadel.HostIngress.RequestContext
  alias Citadel.IntentEnvelope
  alias Citadel.IntentEnvelope.ScopeSelector
  alias Citadel.IntentEnvelope.TargetHint
  alias Citadel.IntentMappingConstraints
  alias Citadel.InvocationRequest.V2, as: InvocationRequestV2
  alias Citadel.LocalAction
  alias Citadel.PlanHints
  alias Citadel.PlanHints.CandidateStep
  alias Citadel.PolicyPacks
  alias Citadel.PolicyPacks.Selection
  alias Citadel.ScopeRef
  alias Citadel.StalenessRequirements
  alias Citadel.TopologyIntent

  @default_requested_ttl_ms 60_000
  @default_execution_family "process"
  @default_placement_intent "host_local"
  @default_wall_clock_budget_ms 60_000
  @allowed_approval_modes ["manual", "auto", "none"]
  @allowed_egress_policies ["blocked", "restricted", "open"]
  @allowed_workspace_mutabilities ["read_only", "read_write", "ephemeral"]
  @allowed_execution_families ["process", "http", "json_rpc", "service"]
  @allowed_placement_intents ["host_local", "remote_scope", "remote_workspace", "ephemeral_session"]
  @allowed_sandbox_levels ["strict", "standard", "none"]

  @type compiled :: %{
          selection: Selection.t(),
          scope_ref: ScopeRef.t(),
          invocation_request: InvocationRequestV2.t(),
          outbox_entry: ActionOutboxEntry.t(),
          entry_id: String.t()
        }

  @spec compile(IntentEnvelope.t() | map() | keyword(), RequestContext.t() | map() | keyword(), [Selection.t() | map()], keyword()) ::
          {:ok, compiled()} | {:rejected, DecisionRejection.t()} | {:error, term()}
  def compile(envelope, request_context, policy_packs, opts \\ []) do
    envelope = normalize_envelope!(envelope)
    request_context = RequestContext.new!(request_context)
    selection = select_policy!(policy_packs, envelope, request_context)

    case IntentMappingConstraints.planning_status(envelope) do
      :plannable ->
        compile_plannable(envelope, request_context, selection, opts)

      {:unplannable, reason_code} ->
        {:rejected, classify_rejection!(request_context, selection, reason_code)}
    end
  rescue
    error in ArgumentError -> {:error, error}
  end

  defp compile_plannable(envelope, request_context, selection, opts) do
    with {:ok, selector} <- first_scope_selector(envelope),
         {:ok, target_hint} <- first_target_hint(envelope),
         {:ok, candidate_step} <- first_candidate_step(envelope),
         {:ok, step_extensions} <- citadel_step_extensions(candidate_step),
         {:ok, execution_intent_family} <- execution_intent_family(step_extensions),
         {:ok, execution_intent} <- execution_intent(step_extensions),
         {:ok, target_id} <- target_id(target_hint, selector),
         {:ok, boundary_intent} <- boundary_intent(envelope, selection, opts),
         {:ok, topology_intent} <-
           topology_intent(
             envelope,
             request_context,
             target_hint,
             execution_intent_family,
             execution_intent,
             step_extensions
           ),
         {:ok, authority_packet} <- authority_packet(request_context, selection, boundary_intent),
         {:ok, execution_governance} <-
           execution_governance(
             request_context,
             selector,
             target_hint,
             candidate_step,
             selection,
             authority_packet,
             boundary_intent,
             topology_intent,
             execution_intent_family,
             step_extensions
           ),
         {:ok, invocation_request} <-
           invocation_request(
             request_context,
             target_hint,
             target_id,
             candidate_step,
             authority_packet,
             boundary_intent,
             topology_intent,
             execution_governance,
             execution_intent_family,
             execution_intent
           ) do
      entry_id = "submit/#{request_context.request_id}"

      {:ok,
       %{
         selection: selection,
         scope_ref: scope_ref(selector, request_context),
         invocation_request: invocation_request,
         outbox_entry:
           outbox_entry(entry_id, request_context, selection, invocation_request, opts),
         entry_id: entry_id
       }}
    else
      {:rejected, %DecisionRejection{} = rejection} ->
        {:rejected, rejection}

      {:error, {:planning, reason_code}} ->
        {:rejected, classify_rejection!(request_context, selection, reason_code)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_envelope!(%IntentEnvelope{} = envelope), do: IntentEnvelope.new!(IntentEnvelope.dump(envelope))
  defp normalize_envelope!(envelope), do: IntentEnvelope.new!(envelope)

  defp select_policy!(policy_packs, envelope, request_context) when is_list(policy_packs) do
    selector = List.first(envelope.scope_selectors)

    if is_nil(selector) do
      raise ArgumentError, "host ingress compilation requires at least one scope selector"
    end

    PolicyPacks.select_profile!(policy_packs, %{
      tenant_id: request_context.tenant_id,
      scope_kind: selector.scope_kind,
      environment: selector.environment || request_context.environment,
      policy_epoch: request_context.policy_epoch
    })
  end

  defp first_scope_selector(%IntentEnvelope{scope_selectors: [%ScopeSelector{} = selector | _rest]}),
    do: {:ok, selector}

  defp first_scope_selector(_envelope), do: {:error, {:planning, "missing_scope_selector"}}

  defp first_target_hint(%IntentEnvelope{target_hints: [%TargetHint{} = hint | _rest]}), do: {:ok, hint}
  defp first_target_hint(_envelope), do: {:error, {:planning, "missing_target_hint"}}

  defp first_candidate_step(%IntentEnvelope{plan_hints: %PlanHints{candidate_steps: [%CandidateStep{} = step | _rest]}}),
    do: {:ok, step}

  defp first_candidate_step(_envelope), do: {:error, {:planning, "missing_candidate_step"}}

  defp citadel_step_extensions(%CandidateStep{extensions: %{"citadel" => extensions}})
       when is_map(extensions),
       do: {:ok, extensions}

  defp citadel_step_extensions(%CandidateStep{}), do: {:ok, %{}}

  defp execution_intent_family(extensions) do
    value = Map.get(extensions, "execution_intent_family", @default_execution_family)

    if value in @allowed_execution_families do
      {:ok, value}
    else
      {:error, {:planning, "unsupported_execution_intent_family"}}
    end
  end

  defp execution_intent(extensions) do
    case Map.get(extensions, "execution_intent") do
      value when is_map(value) ->
        {:ok, value}

      nil ->
        {:error, {:planning, "missing_execution_intent"}}

      _other ->
        {:error, {:planning, "invalid_execution_intent"}}
    end
  end

  defp target_id(%TargetHint{preferred_target_id: target_id}, _selector)
       when is_binary(target_id) and target_id != "",
       do: {:ok, target_id}

  defp target_id(%TargetHint{}, %ScopeSelector{scope_id: scope_id})
       when is_binary(scope_id) and scope_id != "",
       do: {:ok, scope_id}

  defp target_id(_target_hint, _selector), do: {:error, {:planning, "missing_target_id"}}

  defp boundary_intent(envelope, selection, opts) do
    mapping = IntentMappingConstraints.boundary_mapping(envelope)
    ttl_ms = Keyword.get(opts, :requested_ttl_ms, @default_requested_ttl_ms)

    {:ok,
     BoundaryIntent.new!(%{
       boundary_class: mapping.preferred_boundary_class || selection.profiles.boundary_class,
       trust_profile: selection.profiles.trust_profile,
       workspace_profile: selection.profiles.workspace_profile,
       resource_profile: selection.profiles.resource_profile,
       requested_attach_mode: mapping.requested_attach_mode,
       requested_ttl_ms: ttl_ms,
       extensions: %{}
     })}
  end

  defp topology_intent(
         envelope,
         request_context,
         %TargetHint{} = target_hint,
         execution_intent_family,
         execution_intent,
         step_extensions
       ) do
    mapping = IntentMappingConstraints.topology_mapping(envelope)

    preferred_topology =
      case envelope.plan_hints do
        %PlanHints{preferred_topology: value} -> value
        _ -> nil
      end

    routing_hints =
      mapping.routing_hints
      |> Map.merge(preferred_topology_routing_hints(preferred_topology))
      |> Map.put("execution_intent_family", execution_intent_family)
      |> Map.put("execution_intent", execution_intent)
      |> Map.put("downstream_scope", downstream_scope(step_extensions, execution_intent_family, target_hint.target_kind))

    {:ok,
     TopologyIntent.new!(%{
       topology_intent_id: "topology/#{request_context.request_id}",
       session_mode:
         preferred_topology_value(preferred_topology, :session_mode) ||
           Atom.to_string(mapping.session_mode),
       coordination_mode:
         preferred_topology_value(preferred_topology, :coordination_mode) ||
           Atom.to_string(mapping.coordination_mode),
       routing_hints: routing_hints,
       topology_epoch: 0,
       extensions: %{}
     })}
  end

  defp preferred_topology_value(nil, _field), do: nil

  defp preferred_topology_value(preferred_topology, field) do
    preferred_topology
    |> Map.get(field)
    |> case do
      nil -> nil
      value when is_atom(value) -> Atom.to_string(value)
      value -> value
    end
  end

  defp preferred_topology_routing_hints(nil), do: %{}

  defp preferred_topology_routing_hints(preferred_topology) do
    Map.get(preferred_topology, :routing_hints, %{})
  end

  defp downstream_scope(step_extensions, execution_intent_family, target_kind) do
    Map.get(step_extensions, "downstream_scope", "#{execution_intent_family}:#{target_kind}")
  end

  defp authority_packet(request_context, %Selection{} = selection, %BoundaryIntent{} = boundary_intent) do
    {:ok,
     DecisionHash.put_authority_hash!(%{
       contract_version: AuthorityDecisionV1.contract_version(),
       decision_id: "decision/#{request_context.request_id}",
       tenant_id: request_context.tenant_id,
       request_id: request_context.request_id,
       policy_version: selection.policy_version,
       boundary_class: boundary_intent.boundary_class,
       trust_profile: selection.profiles.trust_profile,
       approval_profile: selection.profiles.approval_profile,
       egress_profile: selection.profiles.egress_profile,
       workspace_profile: selection.profiles.workspace_profile,
       resource_profile: selection.profiles.resource_profile,
       extensions: %{
         "citadel" => %{
           "policy_pack_id" => selection.pack_id,
           "host_request_id" => request_context.host_request_id,
           "trace_origin" => request_context.trace_origin
         }
       }
     })}
  end

  defp execution_governance(
         request_context,
         %ScopeSelector{} = selector,
         %TargetHint{} = target_hint,
         %CandidateStep{} = candidate_step,
         selection,
         authority_packet,
         boundary_intent,
         topology_intent,
         execution_intent_family,
         step_extensions
       ) do
    logical_workspace_ref = logical_workspace_ref(selector)

    {:ok,
     ExecutionGovernanceCompiler.compile!(
       authority_packet,
       boundary_intent,
       topology_intent,
       execution_governance_id: "execgov/#{request_context.request_id}",
       sandbox_level: sandbox_level(step_extensions, candidate_step, selection),
       sandbox_egress: sandbox_egress(selection.profiles.egress_profile),
       sandbox_approvals: sandbox_approvals(step_extensions, selection.profiles.approval_profile),
       allowed_tools: normalize_string_list(Map.get(step_extensions, "allowed_tools", [])),
       file_scope_ref: logical_workspace_ref,
       file_scope_hint: selector.workspace_root,
       logical_workspace_ref: logical_workspace_ref,
       workspace_mutability: workspace_mutability(step_extensions, candidate_step),
       execution_family: execution_family(step_extensions, execution_intent_family),
       placement_intent: placement_intent(step_extensions),
       target_kind: target_hint.target_kind,
       node_affinity: normalize_optional_string(Map.get(step_extensions, "node_affinity")),
       allowed_operations: candidate_step.allowed_operations,
       effect_classes: effect_classes(step_extensions, candidate_step),
       cpu_class: normalize_optional_string(Map.get(step_extensions, "cpu_class")),
       memory_class: normalize_optional_string(Map.get(step_extensions, "memory_class")),
       wall_clock_budget_ms:
         normalize_optional_non_neg_integer(
           Map.get(step_extensions, "wall_clock_budget_ms", @default_wall_clock_budget_ms)
         )
     )}
  end

  defp invocation_request(
         request_context,
         %TargetHint{} = target_hint,
         target_id,
         %CandidateStep{} = candidate_step,
         authority_packet,
         boundary_intent,
         topology_intent,
         execution_governance,
         execution_intent_family,
         execution_intent
       ) do
    selected_step_id = selected_step_id(request_context, candidate_step)

    {:ok,
     InvocationRequestV2.new!(%{
       schema_version: InvocationRequestV2.schema_version(),
       invocation_request_id: "invoke/#{request_context.request_id}",
       request_id: request_context.request_id,
       session_id: request_context.session_id,
       tenant_id: request_context.tenant_id,
       trace_id: request_context.trace_id,
       actor_id: request_context.actor_id,
       target_id: target_id,
       target_kind: target_hint.target_kind,
       selected_step_id: selected_step_id,
       allowed_operations: candidate_step.allowed_operations,
       authority_packet: authority_packet,
       boundary_intent: boundary_intent,
       topology_intent: topology_intent,
       execution_governance: execution_governance,
       extensions: %{
         "citadel" => %{
           "execution_intent_family" => execution_intent_family,
           "execution_intent" => execution_intent,
           "ingress_provenance" => %{
             "host_request_id" => request_context.host_request_id,
             "trace_origin" => request_context.trace_origin,
             "idempotency_key" => request_context.idempotency_key,
             "metadata_keys" => request_context.metadata_keys
           }
         }
       }
     })}
  end

  defp outbox_entry(entry_id, request_context, %Selection{} = selection, invocation_request, opts) do
    now = Keyword.get(opts, :inserted_at, DateTime.utc_now())

    ActionOutboxEntry.new!(%{
      schema_version: ActionOutboxEntry.schema_version(),
      entry_id: entry_id,
      causal_group_id: request_context.request_id,
      action:
        LocalAction.new!(%{
          action_kind: InvocationPayload.action_kind(),
          payload: InvocationPayload.encode!(invocation_request),
          extensions: %{}
        }),
      inserted_at: now,
      replay_status: :pending,
      durable_receipt_ref: nil,
      attempt_count: 0,
      max_attempts: 3,
      backoff_policy:
        BackoffPolicy.new!(%{
          strategy: :fixed,
          base_delay_ms: 25,
          max_delay_ms: 250,
          linear_step_ms: nil,
          multiplier: nil,
          jitter_mode: :entry_stable,
          jitter_window_ms: 10,
          extensions: %{}
        }),
      next_attempt_at: nil,
      last_error_code: nil,
      dead_letter_reason: nil,
      ordering_mode: :strict,
      staleness_mode: :requires_check,
      staleness_requirements:
        StalenessRequirements.new!(%{
          snapshot_seq: 0,
          policy_epoch: selection.policy_epoch,
          topology_epoch: nil,
          scope_catalog_epoch: nil,
          service_admission_epoch: nil,
          project_binding_epoch: nil,
          boundary_epoch: nil,
          required_binding_id: nil,
          required_boundary_ref: nil,
          extensions: %{}
        }),
      extensions: %{
        "host_ingress" => %{
          "request_id" => request_context.request_id,
          "trace_id" => request_context.trace_id
        }
      }
    })
  end

  defp scope_ref(%ScopeSelector{} = selector, %RequestContext{} = request_context) do
    ScopeRef.new!(%{
      scope_id: selector.scope_id || logical_workspace_ref(selector),
      scope_kind: selector.scope_kind,
      workspace_root: selector.workspace_root || "/scopes/#{request_context.session_id}",
      environment: selector.environment || request_context.environment || "unknown",
      catalog_epoch: 0,
      extensions: %{}
    })
  end

  defp logical_workspace_ref(%ScopeSelector{} = selector) do
    cond do
      is_binary(selector.scope_id) and selector.scope_id != "" and
          String.starts_with?(selector.scope_id, "workspace://") ->
        selector.scope_id

      is_binary(selector.scope_id) and selector.scope_id != "" ->
        "workspace://#{selector.scope_kind}/#{selector.scope_id}"

      is_binary(selector.workspace_root) and selector.workspace_root != "" ->
        "workspace://#{selector.scope_kind}/#{Path.basename(selector.workspace_root)}"

      true ->
        raise ArgumentError,
              "host ingress compilation requires scope selector scope_id or workspace_root"
    end
  end

  defp sandbox_level(step_extensions, %CandidateStep{} = candidate_step, selection) do
    case Map.get(step_extensions, "sandbox_level") do
      value when value in @allowed_sandbox_levels ->
        value

      _other ->
        cond do
          Enum.any?(candidate_step.allowed_operations, &String.contains?(&1, "write")) -> "strict"
          selection.profiles.approval_profile in ["manual", "approval_required"] -> "strict"
          true -> "standard"
        end
    end
  end

  defp sandbox_egress(value) when value in @allowed_egress_policies, do: value
  defp sandbox_egress(_value), do: "restricted"

  defp sandbox_approvals(step_extensions, approval_profile) do
    case Map.get(step_extensions, "sandbox_approvals") do
      value when value in @allowed_approval_modes ->
        value

      _other when approval_profile in ["manual", "approval_required"] ->
        "manual"

      _other when approval_profile in ["none", "approval_none"] ->
        "none"

      _other ->
        "auto"
    end
  end

  defp workspace_mutability(step_extensions, %CandidateStep{} = candidate_step) do
    case Map.get(step_extensions, "workspace_mutability") do
      value when value in @allowed_workspace_mutabilities ->
        value

      _other ->
        if Enum.any?(candidate_step.allowed_operations, fn operation ->
             String.contains?(operation, "write") or String.contains?(operation, "patch")
           end) do
          "read_write"
        else
          "read_only"
        end
    end
  end

  defp execution_family(step_extensions, fallback) do
    case Map.get(step_extensions, "execution_family", fallback) do
      value when value in @allowed_execution_families -> value
      _other -> fallback
    end
  end

  defp placement_intent(step_extensions) do
    case Map.get(step_extensions, "placement_intent", @default_placement_intent) do
      value when value in @allowed_placement_intents -> value
      _other -> @default_placement_intent
    end
  end

  defp effect_classes(step_extensions, %CandidateStep{} = candidate_step) do
    case Map.get(step_extensions, "effect_classes") do
      value when is_list(value) ->
        normalize_string_list(value)

      _other ->
        infer_effect_classes(candidate_step.allowed_operations)
    end
  end

  defp infer_effect_classes(allowed_operations) do
    classes =
      Enum.reduce(allowed_operations, [], fn operation, acc ->
        acc
        |> maybe_prepend("filesystem", String.contains?(operation, "write") or String.contains?(operation, "patch"))
        |> maybe_prepend("process", String.contains?(operation, "exec"))
      end)

    Enum.reverse(classes)
  end

  defp selected_step_id(%RequestContext{} = request_context, %CandidateStep{} = candidate_step) do
    case Map.get(candidate_step.extensions, "step_id") || Map.get(candidate_step.extensions, :step_id) do
      value when is_binary(value) and value != "" -> value
      _other -> "step/#{request_context.request_id}/#{candidate_step.capability_id}"
    end
  end

  defp classify_rejection!(request_context, selection, reason_code) do
    DecisionRejectionClassifier.classify!(
      %{
        rejection_id: "rejection/#{request_context.request_id}/#{reason_code}",
        stage: :planning,
        reason_code: reason_code,
        summary: rejection_summary(reason_code),
        causes: rejection_causes(reason_code),
        extensions: %{
          "request_id" => request_context.request_id,
          "session_id" => request_context.session_id,
          "trace_id" => request_context.trace_id
        }
      },
      selection
    )
  end

  defp rejection_summary("missing_scope_selector"), do: "structured ingress requires at least one scope selector"
  defp rejection_summary("missing_target_hint"), do: "structured ingress requires at least one target hint"
  defp rejection_summary("missing_candidate_step"), do: "structured ingress requires at least one candidate step"
  defp rejection_summary("missing_execution_intent"), do: "candidate step is missing execution intent details"
  defp rejection_summary("invalid_execution_intent"), do: "candidate step execution intent must be a JSON object"
  defp rejection_summary("unsupported_execution_intent_family"), do: "candidate step requests an unsupported execution family"
  defp rejection_summary("missing_target_id"), do: "structured ingress requires a target identity"
  defp rejection_summary(other), do: other

  defp rejection_causes(reason_code)
       when reason_code in [
              "missing_scope_selector",
              "missing_target_hint",
              "missing_candidate_step",
              "missing_execution_intent",
              "invalid_execution_intent",
              "unsupported_execution_intent_family",
              "missing_target_id"
            ],
       do: [:planning]

  defp rejection_causes(_other), do: [:planning]

  defp normalize_string_list(value) when is_list(value) do
    value
    |> Enum.flat_map(fn
      item when is_binary(item) and item != "" -> [item]
      _other -> []
    end)
    |> Enum.uniq()
  end

  defp normalize_optional_string(nil), do: nil
  defp normalize_optional_string(value) when is_binary(value) and value != "", do: value
  defp normalize_optional_string(_other), do: nil

  defp normalize_optional_non_neg_integer(nil), do: nil
  defp normalize_optional_non_neg_integer(value) when is_integer(value) and value >= 0, do: value
  defp normalize_optional_non_neg_integer(_other), do: nil

  defp maybe_prepend(list, _value, false), do: list

  defp maybe_prepend(list, value, true) do
    if value in list do
      list
    else
      [value | list]
    end
  end
end
