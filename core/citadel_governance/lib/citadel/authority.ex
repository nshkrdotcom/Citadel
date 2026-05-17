defmodule Citadel.Authority.Decision do
  @moduledoc """
  Provider-neutral authority decision for command prechecks and resolved plans.
  """

  @fields [
    :result,
    :stage,
    :reason_code,
    :actor_ref,
    :tenant_ref,
    :installation_ref,
    :operation_class,
    :capability,
    :manifest_ref,
    :operation_ref,
    :binding_ref,
    :credential_scope_ref,
    :side_effect_class,
    :required_scopes,
    :confirmation_policy_ref,
    :policy_hash,
    :retryable?,
    :recovery_owner,
    :blast_radius,
    :propagation_target,
    :operator_action,
    :metadata
  ]

  @enforce_keys [
    :result,
    :stage,
    :actor_ref,
    :tenant_ref,
    :installation_ref,
    :operation_class,
    :capability,
    :retryable?,
    :recovery_owner,
    :blast_radius,
    :propagation_target,
    :operator_action
  ]
  defstruct @fields

  @type t :: %__MODULE__{}
end

defmodule Citadel.Authority do
  @moduledoc """
  Generic authority core for resolved operation plans.

  The first decision layer is intentionally pure: actor, tenant,
  installation, operation class, and capability. Manifest, binding,
  credential-scope, side-effect, and confirmation constraints are additive
  checks after the capability result.
  """

  alias Citadel.Authority.Decision
  alias Citadel.ContractCore.Value

  @operation_classes [
    :source_read,
    :source_write,
    :runtime_session,
    :runtime_tool_invocation,
    :evidence_collection,
    :resource_effect,
    :lower_read,
    :trace_replay,
    :review_decision
  ]

  @decision_defaults %{
    retryable?: false,
    recovery_owner: :platform_citadel_operator,
    blast_radius: :tenant_installation_operation,
    propagation_target: :appkit_error_aitrace_event_operator_alert,
    operator_action: :review_policy_or_binding_configuration
  }

  @plan_fields [
    :actor_ref,
    :tenant_ref,
    :installation_ref,
    :operation_class,
    :capability,
    :manifest_ref,
    :operation_ref,
    :binding_ref,
    :credential_scope_ref,
    :side_effect_class,
    :required_scopes,
    :confirmation_policy_ref,
    :trace_ref,
    :policy_hash,
    :metadata
  ]

  @spec operation_classes() :: [atom()]
  def operation_classes, do: @operation_classes

  @spec decide_capability(
          String.t(),
          String.t(),
          String.t(),
          atom() | String.t(),
          String.t(),
          keyword()
        ) ::
          {:ok, Decision.t()} | {:error, Exception.t()}
  def decide_capability(
        actor_ref,
        tenant_ref,
        installation_ref,
        operation_class,
        capability,
        opts \\ []
      ) do
    request = %{
      actor_ref: Value.string!(actor_ref, "Citadel.Authority.actor_ref"),
      tenant_ref: Value.string!(tenant_ref, "Citadel.Authority.tenant_ref"),
      installation_ref: Value.string!(installation_ref, "Citadel.Authority.installation_ref"),
      operation_class:
        Value.enum!(operation_class, @operation_classes, "Citadel.Authority.operation_class"),
      capability: Value.string!(capability, "Citadel.Authority.capability")
    }

    {:ok, capability_decision(request, opts)}
  rescue
    error in ArgumentError -> {:error, error}
  end

  @spec authorize_resolved_plan(map() | keyword(), keyword()) ::
          {:ok, Decision.t()} | {:error, Exception.t()}
  def authorize_resolved_plan(attrs, opts \\ []) when is_map(attrs) or is_list(attrs) do
    request = normalize_plan_request!(attrs)

    {:ok, capability} =
      decide_capability(
        request.actor_ref,
        request.tenant_ref,
        request.installation_ref,
        request.operation_class,
        request.capability,
        opts
      )

    case capability.result do
      :allowed -> {:ok, resolved_plan_decision(request, opts)}
      _result -> {:ok, capability}
    end
  rescue
    error in ArgumentError -> {:error, error}
  end

  defp capability_decision(request, opts) do
    allowed_operation_classes = option_atoms(opts, :allowed_operation_classes, @operation_classes)
    allowed_capabilities = option_strings(opts, :allowed_capabilities, :any)
    review_required = option_atoms(opts, :review_required_operation_classes, [])

    cond do
      request.operation_class not in allowed_operation_classes ->
        decision(:rejected, :capability, request, "operation_class_not_allowed")

      allowed_capabilities != :any and request.capability not in allowed_capabilities ->
        decision(:rejected, :capability, request, "capability_not_allowed")

      request.operation_class in review_required ->
        decision(:review_required, :capability, request, "review_required_for_operation_class")

      true ->
        decision(:allowed, :capability, request, nil)
    end
  end

  defp resolved_plan_decision(request, opts) do
    cond do
      not allowed_value?(request.manifest_ref, option_strings(opts, :allowed_manifest_refs, :any)) ->
        decision(:rejected, :resolved_plan, request, "manifest_ref_not_allowed")

      not allowed_value?(request.binding_ref, option_strings(opts, :allowed_binding_refs, :any)) ->
        decision(:rejected, :resolved_plan, request, "binding_ref_not_allowed")

      not allowed_value?(
        request.credential_scope_ref,
        option_strings(opts, :allowed_credential_scope_refs, :any)
      ) ->
        decision(:rejected, :resolved_plan, request, "credential_scope_not_allowed")

      not allowed_value?(
        request.side_effect_class,
        option_strings(opts, :allowed_side_effect_classes, :any)
      ) ->
        decision(:rejected, :resolved_plan, request, "side_effect_class_not_allowed")

      disallowed_scopes(request, opts) != [] ->
        decision(:rejected, :resolved_plan, request, "required_scope_not_allowed")

      missing_confirmation_policy?(request, opts) ->
        decision(:rejected, :resolved_plan, request, "missing_confirmation_policy")

      true ->
        decision(:allowed, :resolved_plan, request, nil)
    end
  end

  defp normalize_plan_request!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.Authority resolved plan request", @plan_fields)

    %{
      actor_ref:
        required_string(attrs, :actor_ref, "Citadel.Authority resolved plan request.actor_ref"),
      tenant_ref:
        required_string(attrs, :tenant_ref, "Citadel.Authority resolved plan request.tenant_ref"),
      installation_ref:
        required_string(
          attrs,
          :installation_ref,
          "Citadel.Authority resolved plan request.installation_ref"
        ),
      operation_class:
        Value.required(
          attrs,
          :operation_class,
          "Citadel.Authority resolved plan request",
          &Value.enum!(
            &1,
            @operation_classes,
            "Citadel.Authority resolved plan request.operation_class"
          )
        ),
      capability:
        required_string(attrs, :capability, "Citadel.Authority resolved plan request.capability"),
      manifest_ref:
        required_string(
          attrs,
          :manifest_ref,
          "Citadel.Authority resolved plan request.manifest_ref"
        ),
      operation_ref:
        required_string(
          attrs,
          :operation_ref,
          "Citadel.Authority resolved plan request.operation_ref"
        ),
      binding_ref:
        required_string(
          attrs,
          :binding_ref,
          "Citadel.Authority resolved plan request.binding_ref"
        ),
      credential_scope_ref:
        required_string(
          attrs,
          :credential_scope_ref,
          "Citadel.Authority resolved plan request.credential_scope_ref"
        ),
      side_effect_class:
        required_string(
          attrs,
          :side_effect_class,
          "Citadel.Authority resolved plan request.side_effect_class"
        ),
      required_scopes:
        Value.optional(
          attrs,
          :required_scopes,
          "Citadel.Authority resolved plan request",
          &Value.unique_strings!(&1, "Citadel.Authority resolved plan request.required_scopes"),
          []
        ),
      confirmation_policy_ref:
        Value.optional(
          attrs,
          :confirmation_policy_ref,
          "Citadel.Authority resolved plan request",
          &Value.string!(&1, "Citadel.Authority resolved plan request.confirmation_policy_ref"),
          nil
        ),
      trace_ref:
        Value.optional(
          attrs,
          :trace_ref,
          "Citadel.Authority resolved plan request",
          &Value.string!(&1, "Citadel.Authority resolved plan request.trace_ref"),
          nil
        ),
      policy_hash:
        Value.optional(
          attrs,
          :policy_hash,
          "Citadel.Authority resolved plan request",
          &Value.string!(&1, "Citadel.Authority resolved plan request.policy_hash"),
          nil
        ),
      metadata:
        Value.optional(
          attrs,
          :metadata,
          "Citadel.Authority resolved plan request",
          &Value.json_object!(&1, "Citadel.Authority resolved plan request.metadata"),
          %{}
        )
    }
  end

  defp decision(result, stage, request, reason_code) do
    struct!(
      Decision,
      @decision_defaults
      |> Map.merge(%{
        result: result,
        stage: stage,
        reason_code: reason_code,
        actor_ref: request.actor_ref,
        tenant_ref: request.tenant_ref,
        installation_ref: request.installation_ref,
        operation_class: request.operation_class,
        capability: request.capability,
        manifest_ref: Map.get(request, :manifest_ref),
        operation_ref: Map.get(request, :operation_ref),
        binding_ref: Map.get(request, :binding_ref),
        credential_scope_ref: Map.get(request, :credential_scope_ref),
        side_effect_class: Map.get(request, :side_effect_class),
        required_scopes: Map.get(request, :required_scopes, []),
        confirmation_policy_ref: Map.get(request, :confirmation_policy_ref),
        policy_hash: Map.get(request, :policy_hash),
        metadata: Map.get(request, :metadata, %{})
      })
    )
  end

  defp missing_confirmation_policy?(request, opts) do
    confirmation_required =
      option_atoms(opts, :confirmation_required_operation_classes, [
        :source_write,
        :resource_effect
      ])

    request.operation_class in confirmation_required and is_nil(request.confirmation_policy_ref)
  end

  defp disallowed_scopes(request, opts) do
    case option_strings(opts, :allowed_required_scopes, :any) do
      :any -> []
      allowed -> Enum.reject(request.required_scopes, &(&1 in allowed))
    end
  end

  defp allowed_value?(_value, :any), do: true
  defp allowed_value?(value, allowed), do: value in allowed

  defp required_string(attrs, field, label) do
    Value.required(attrs, field, "Citadel.Authority resolved plan request", fn value ->
      Value.string!(value, label)
    end)
  end

  defp option_atoms(opts, field, default) do
    opts
    |> Keyword.get(field, default)
    |> case do
      :any ->
        :any

      values when is_list(values) ->
        Enum.map(values, &Value.enum!(&1, @operation_classes, "#{field}"))
    end
  end

  defp option_strings(opts, field, default) do
    opts
    |> Keyword.get(field, default)
    |> case do
      :any -> :any
      values when is_list(values) -> Enum.map(values, &Value.string!(&1, "#{field}"))
    end
  end
end
