defmodule Citadel.AgentRuntimePolicyProjectionCompiler do
  @moduledoc """
  Compiles selected Citadel policy into an agent runtime policy projection.

  The compiler fails closed. It does not infer lower posture from runtime
  package details, raw endpoint strings, or provider-specific dispatch names.
  """

  alias Citadel.AgentRuntimePolicyProjection
  alias Citadel.ContractCore.Value
  alias Citadel.PolicyPacks.AgentRuntimePolicy
  alias Citadel.PolicyPacks.Selection

  @attrs_schema [
    :projection_ref,
    :authority_ref,
    :tenant_ref,
    :requested_runtime_family,
    :requested_capability_class,
    :skill_ref,
    :interop_ref,
    :raw_endpoint_ref,
    :credential_posture,
    :budget
  ]

  @spec compile(Selection.t(), map() | keyword()) ::
          {:ok, AgentRuntimePolicyProjection.t()} | {:error, {:denied, atom(), map()}}
  def compile(%Selection{} = selection, attrs) do
    with {:ok, attrs} <- normalize_attrs(attrs),
         {:ok, policy} <- fetch_policy(selection),
         :ok <- reject_raw_endpoint(attrs, selection),
         {:ok, _requested_runtime_family} <- requested_runtime_family(attrs, selection, policy),
         {:ok, requested_capability_class} <- requested_capability_class(attrs, selection, policy),
         :ok <- check_skill(attrs, selection, policy, requested_capability_class),
         :ok <- check_interop(attrs, selection, policy),
         {:ok, credential_posture} <- credential_posture(attrs, selection, policy),
         {:ok, budget} <- budget(attrs, selection, policy) do
      projection =
        AgentRuntimePolicyProjection.new!(%{
          projection_ref:
            required_string(
              attrs,
              :projection_ref,
              "projection_ref",
              "agent-policy-projection://"
            ),
          authority_ref: required_string(attrs, :authority_ref, "authority_ref", "authority://"),
          tenant_ref: required_string(attrs, :tenant_ref, "tenant_ref", "tenant://"),
          allowed_runtime_families: policy_runtime_families(policy),
          allowed_capability_classes:
            policy_capability_classes(policy.allowed_capability_classes),
          denied_capability_classes: policy_capability_classes(policy.denied_capability_classes),
          skill_allowlist_refs: policy.skill_allowlist_refs,
          interop_allowlist_refs: policy.interop_allowlist_refs,
          approval_requirements: policy_capability_classes(policy.approval_requirements),
          network_posture:
            policy_enum(policy.network_posture, AgentRuntimePolicyProjection, :network_posture),
          artifact_posture:
            policy_enum(policy.artifact_posture, AgentRuntimePolicyProjection, :artifact_posture),
          credential_posture: credential_posture,
          budget: budget,
          redaction_posture:
            policy_enum(
              policy.redaction_posture,
              AgentRuntimePolicyProjection,
              :redaction_posture
            ),
          revision: policy.revision
        })

      {:ok, projection}
    end
  rescue
    error in ArgumentError ->
      {:error,
       {:denied, :invalid_agent_runtime_policy_projection, %{message: Exception.message(error)}}}
  end

  @spec compile!(Selection.t(), map() | keyword()) :: AgentRuntimePolicyProjection.t()
  def compile!(%Selection{} = selection, attrs) do
    case compile(selection, attrs) do
      {:ok, projection} ->
        projection

      {:error, {:denied, reason, facts}} ->
        raise ArgumentError,
              "agent runtime policy projection denied: #{inspect(reason)} #{inspect(facts)}"
    end
  end

  defp normalize_attrs(attrs) do
    {:ok,
     Value.normalize_attrs!(attrs, "Citadel.AgentRuntimePolicyProjectionCompiler", @attrs_schema)}
  rescue
    error in ArgumentError ->
      deny(:invalid_request, %{message: Exception.message(error)})
  end

  defp fetch_policy(%Selection{agent_runtime_policy: %AgentRuntimePolicy{} = policy}),
    do: {:ok, policy}

  defp fetch_policy(%Selection{} = selection) do
    deny(:missing_agent_runtime_policy, %{pack_id: selection.pack_id})
  end

  defp reject_raw_endpoint(attrs, selection) do
    case Value.optional(
           attrs,
           :raw_endpoint_ref,
           "Citadel.AgentRuntimePolicyProjectionCompiler",
           fn value ->
             Value.string!(
               value,
               "Citadel.AgentRuntimePolicyProjectionCompiler.raw_endpoint_ref"
             )
           end,
           nil
         ) do
      nil ->
        :ok

      raw_endpoint_ref ->
        deny(:raw_endpoint_not_allowed, selection_facts(selection, raw_endpoint_ref))
    end
  end

  defp requested_runtime_family(attrs, selection, policy) do
    requested =
      Value.required(
        attrs,
        :requested_runtime_family,
        "Citadel.AgentRuntimePolicyProjectionCompiler",
        fn value ->
          Value.enum!(
            value,
            AgentRuntimePolicyProjection.runtime_families(),
            "Citadel.AgentRuntimePolicyProjectionCompiler.requested_runtime_family"
          )
        end
      )

    if Atom.to_string(requested) in policy.allowed_runtime_families do
      {:ok, requested}
    else
      deny(:forbidden_runtime_family, %{
        pack_id: selection.pack_id,
        requested_runtime_family: Atom.to_string(requested),
        allowed_runtime_families: policy.allowed_runtime_families
      })
    end
  end

  defp requested_capability_class(attrs, selection, policy) do
    requested =
      Value.required(
        attrs,
        :requested_capability_class,
        "Citadel.AgentRuntimePolicyProjectionCompiler",
        fn value ->
          Value.enum!(
            value,
            AgentRuntimePolicyProjection.capability_classes(),
            "Citadel.AgentRuntimePolicyProjectionCompiler.requested_capability_class"
          )
        end
      )

    requested_string = Atom.to_string(requested)

    cond do
      requested_string in policy.denied_capability_classes ->
        deny(:capability_class_denied, %{
          pack_id: selection.pack_id,
          requested_capability_class: requested_string,
          denied_capability_classes: policy.denied_capability_classes
        })

      requested_string in policy.allowed_capability_classes ->
        {:ok, requested}

      true ->
        deny(:capability_class_not_allowed, %{
          pack_id: selection.pack_id,
          requested_capability_class: requested_string,
          allowed_capability_classes: policy.allowed_capability_classes
        })
    end
  end

  defp check_skill(attrs, selection, policy, :skill_invocation) do
    skill_ref = optional_string(attrs, :skill_ref, "skill_ref")

    cond do
      is_nil(skill_ref) ->
        deny(:missing_skill_package, %{pack_id: selection.pack_id})

      skill_ref in policy.skill_allowlist_refs ->
        :ok

      true ->
        deny(:unknown_skill_package, %{
          pack_id: selection.pack_id,
          skill_ref: skill_ref,
          skill_allowlist_refs: policy.skill_allowlist_refs
        })
    end
  end

  defp check_skill(attrs, selection, policy, _requested_capability_class) do
    case optional_string(attrs, :skill_ref, "skill_ref") do
      nil ->
        :ok

      skill_ref ->
        if skill_ref in policy.skill_allowlist_refs do
          :ok
        else
          deny(:unknown_skill_package, %{
            pack_id: selection.pack_id,
            skill_ref: skill_ref,
            skill_allowlist_refs: policy.skill_allowlist_refs
          })
        end
    end
  end

  defp check_interop(attrs, selection, policy) do
    case optional_string(attrs, :interop_ref, "interop_ref") do
      nil ->
        :ok

      interop_ref ->
        if interop_ref in policy.interop_allowlist_refs do
          :ok
        else
          deny(:unknown_interop_descriptor, %{
            pack_id: selection.pack_id,
            interop_ref: interop_ref,
            interop_allowlist_refs: policy.interop_allowlist_refs
          })
        end
    end
  end

  defp credential_posture(attrs, selection, policy) do
    case Value.optional(
           attrs,
           :credential_posture,
           "Citadel.AgentRuntimePolicyProjectionCompiler",
           fn value ->
             Value.enum!(
               value,
               [:lease_only],
               "Citadel.AgentRuntimePolicyProjectionCompiler.credential_posture"
             )
           end,
           nil
         ) do
      nil ->
        deny(:missing_credential_posture, %{pack_id: selection.pack_id})

      posture ->
        if Atom.to_string(posture) == policy.credential_posture do
          {:ok, posture}
        else
          deny(:credential_posture_not_allowed, %{
            pack_id: selection.pack_id,
            requested_credential_posture: Atom.to_string(posture),
            allowed_credential_posture: policy.credential_posture
          })
        end
    end
  end

  defp budget(attrs, selection, policy) do
    requested =
      Value.optional(
        attrs,
        :budget,
        "Citadel.AgentRuntimePolicyProjectionCompiler",
        &normalize_budget/1,
        policy.budget
      )

    if budget_within_policy?(requested, policy.budget) do
      {:ok, requested}
    else
      deny(:budget_exceeds_policy, %{
        pack_id: selection.pack_id,
        requested_budget: requested,
        policy_budget: policy.budget
      })
    end
  end

  defp normalize_budget(value) do
    attrs =
      Value.normalize_attrs!(
        value,
        "Citadel.AgentRuntimePolicyProjectionCompiler.budget",
        [:wall_clock_ms, :output_bytes, :tool_calls]
      )

    %{
      wall_clock_ms: budget_field(attrs, :wall_clock_ms),
      output_bytes: budget_field(attrs, :output_bytes),
      tool_calls: budget_field(attrs, :tool_calls)
    }
  end

  defp budget_field(attrs, field) do
    Value.required(
      attrs,
      field,
      "Citadel.AgentRuntimePolicyProjectionCompiler.budget",
      fn value ->
        Value.non_neg_integer!(
          value,
          "Citadel.AgentRuntimePolicyProjectionCompiler.budget.#{field}"
        )
      end
    )
  end

  defp budget_within_policy?(requested, policy_budget) do
    requested.wall_clock_ms <= policy_budget.wall_clock_ms and
      requested.output_bytes <= policy_budget.output_bytes and
      requested.tool_calls <= policy_budget.tool_calls
  end

  defp required_string(attrs, field, label, prefix) do
    attrs
    |> Value.required(field, "Citadel.AgentRuntimePolicyProjectionCompiler", fn value ->
      Value.string!(value, "Citadel.AgentRuntimePolicyProjectionCompiler.#{label}")
    end)
    |> require_prefix!(label, prefix)
  end

  defp optional_string(attrs, field, label) do
    Value.optional(
      attrs,
      field,
      "Citadel.AgentRuntimePolicyProjectionCompiler",
      fn value ->
        Value.string!(value, "Citadel.AgentRuntimePolicyProjectionCompiler.#{label}")
      end,
      nil
    )
  end

  defp require_prefix!(value, label, prefix) do
    if String.starts_with?(value, prefix) do
      value
    else
      raise ArgumentError,
            "Citadel.AgentRuntimePolicyProjectionCompiler.#{label} must start with #{inspect(prefix)}"
    end
  end

  defp policy_runtime_families(%AgentRuntimePolicy{} = policy) do
    Enum.map(policy.allowed_runtime_families, fn family ->
      Value.enum!(
        family,
        AgentRuntimePolicyProjection.runtime_families(),
        "Citadel.AgentRuntimePolicyProjectionCompiler.policy.allowed_runtime_families"
      )
    end)
  end

  defp policy_capability_classes(classes) do
    Enum.map(classes, fn class ->
      Value.enum!(
        class,
        AgentRuntimePolicyProjection.capability_classes(),
        "Citadel.AgentRuntimePolicyProjectionCompiler.policy.capability_classes"
      )
    end)
  end

  defp policy_enum(value, AgentRuntimePolicyProjection, :network_posture) do
    Value.enum!(
      value,
      [:none, :restricted, :approved_egress],
      "Citadel.AgentRuntimePolicyProjectionCompiler.policy.network_posture"
    )
  end

  defp policy_enum(value, AgentRuntimePolicyProjection, :artifact_posture) do
    Value.enum!(
      value,
      [:claim_checked],
      "Citadel.AgentRuntimePolicyProjectionCompiler.policy.artifact_posture"
    )
  end

  defp policy_enum(value, AgentRuntimePolicyProjection, :redaction_posture) do
    Value.enum!(
      value,
      [:product_safe],
      "Citadel.AgentRuntimePolicyProjectionCompiler.policy.redaction_posture"
    )
  end

  defp selection_facts(%Selection{} = selection, value) do
    %{pack_id: selection.pack_id, value: value}
  end

  defp deny(reason, facts), do: {:error, {:denied, reason, facts}}
end
