defmodule Citadel.HostIngress.RunRequestLowering do
  @moduledoc """
  Pure lowering from `Citadel.HostIngress.RunRequest` into
  `Citadel.IntentEnvelope`.
  """

  alias Citadel.HostIngress.RunRequest
  alias Citadel.IntentEnvelope

  @spec intent_envelope!(RunRequest.t() | RunRequest.attrs()) :: IntentEnvelope.t()
  def intent_envelope!(run_request) do
    run_request = RunRequest.new!(run_request)

    IntentEnvelope.new!(%{
      intent_envelope_id: run_request.run_request_id,
      scope_selectors: [scope_selector(run_request)],
      desired_outcome: desired_outcome(run_request),
      constraints: constraints(run_request),
      risk_hints: Enum.map(run_request.risk_hints, &risk_hint/1),
      success_criteria: Enum.map(run_request.success_criteria, &success_criterion/1),
      target_hints: [target_hint(run_request)],
      plan_hints: plan_hints(run_request),
      resolution_provenance: resolution_provenance(run_request),
      extensions: envelope_extensions(run_request)
    })
  end

  defp scope_selector(%RunRequest{} = run_request) do
    %{
      scope_kind: run_request.scope.scope_kind,
      scope_id: run_request.scope.scope_id,
      workspace_root: run_request.scope.workspace_root,
      environment: run_request.scope.environment,
      preference: run_request.scope.preference,
      extensions: %{}
    }
  end

  defp desired_outcome(%RunRequest{} = run_request) do
    %{
      outcome_kind: :invoke_capability,
      requested_capabilities: [run_request.capability_id],
      result_kind: run_request.result_kind,
      subject_selectors: run_request.subject_selectors,
      extensions: %{
        "objective" => run_request.objective
      }
    }
  end

  defp constraints(%RunRequest{} = run_request) do
    %{
      boundary_requirement: run_request.constraints.boundary_requirement,
      allowed_boundary_classes: run_request.constraints.allowed_boundary_classes,
      allowed_service_ids: run_request.constraints.allowed_service_ids,
      forbidden_service_ids: run_request.constraints.forbidden_service_ids,
      max_steps: run_request.constraints.max_steps,
      review_required: run_request.constraints.review_required,
      extensions: %{}
    }
  end

  defp risk_hint(attrs) do
    Map.merge(
      %{
        risk_code: "higher_order_run",
        severity: :medium,
        requires_governance: false,
        extensions: %{}
      },
      attrs
    )
  end

  defp success_criterion(attrs) do
    Map.merge(
      %{
        criterion_kind: :completion,
        metric: "runtime_submission_completed",
        target: %{},
        required: true,
        extensions: %{}
      },
      attrs
    )
  end

  defp target_hint(%RunRequest{} = run_request) do
    %{
      target_kind: run_request.target.target_kind,
      preferred_target_id: run_request.target.target_id,
      preferred_service_id: run_request.target.service_id,
      preferred_boundary_class: run_request.target.boundary_class,
      session_mode_preference: run_request.target.session_mode_preference,
      coordination_mode_preference: run_request.target.coordination_mode_preference,
      routing_tags: run_request.target.routing_tags,
      extensions: %{}
    }
  end

  defp plan_hints(%RunRequest{} = run_request) do
    %{
      candidate_steps: [
        %{
          step_kind: "capability",
          capability_id: run_request.capability_id,
          allowed_operations: run_request.execution.allowed_operations,
          extensions: candidate_step_extensions(run_request)
        }
      ],
      preferred_targets: [],
      preferred_topology: nil,
      budget_hints: nil,
      extensions: %{}
    }
  end

  defp candidate_step_extensions(%RunRequest{} = run_request) do
    step_id_extensions =
      case run_request.execution.step_id do
        value when is_binary(value) and value != "" -> %{"step_id" => value}
        _other -> %{}
      end

    Map.merge(step_id_extensions, %{
      "citadel" => %{
        "execution_intent_family" => run_request.execution.execution_intent_family,
        "execution_intent" => run_request.execution.execution_intent,
        "allowed_tools" => run_request.execution.allowed_tools,
        "effect_classes" => run_request.execution.effect_classes,
        "workspace_mutability" => run_request.execution.workspace_mutability,
        "placement_intent" => run_request.execution.placement_intent,
        "downstream_scope" => run_request.execution.downstream_scope
      }
    })
  end

  defp resolution_provenance(%RunRequest{} = run_request) do
    Map.merge(
      run_request.resolution_provenance,
      %{
        source_kind: run_request.resolution_provenance.source_kind,
        extensions:
          Map.merge(run_request.resolution_provenance.extensions, %{
            "run_request_id" => run_request.run_request_id
          })
      }
    )
  end

  defp envelope_extensions(%RunRequest{} = run_request) do
    Map.merge(run_request.extensions, %{
      "higher_order" => %{
        "run_request_id" => run_request.run_request_id,
        "capability_id" => run_request.capability_id,
        "objective" => run_request.objective
      }
    })
  end
end
