defmodule Citadel.PolicyPacksAdversarialTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import StreamData

  alias Citadel.PolicyPacks
  alias Citadel.PolicyPacks.PolicyPack
  alias Citadel.PolicyPacks.Selection
  alias Citadel.PolicyPacks.Selector

  property "selector adversarial variants never escape as generic crashes" do
    check all(selector_attrs <- selector_candidate(), selection_input <- selection_input_candidate()) do
      case safe_call(fn -> Selector.new!(selector_attrs) end) do
        {:ok, %Selector{} = selector} ->
          assert_packet_safe(fn -> Selector.matches?(selector, selection_input) end, &is_boolean/1)

        {:error, %ArgumentError{}} ->
          :ok

        {:error, error} ->
          flunk("unexpected selector construction crash: #{inspect(error.__struct__)}")
      end
    end
  end

  property "policy pack adversarial variants round trip or fail explicitly" do
    check all(pack_attrs <- policy_pack_candidate()) do
      assert_packet_safe(fn -> PolicyPack.new!(pack_attrs) end, fn
        %PolicyPack{} = pack ->
          pack == PolicyPack.new!(PolicyPack.dump(pack))

        _ ->
          false
      end)
    end
  end

  property "policy selection adversarial variants return packet-valid results or explicit validation failures" do
    check all(
            packs <- policy_pack_list_candidate(),
            selection_input <- selection_input_candidate()
          ) do
      assert_packet_safe(fn -> PolicyPacks.select_profile!(packs, selection_input) end, fn
        %Selection{} -> true
        _ -> false
      end)

      assert_packet_safe(fn -> PolicyPacks.select_profile(packs, selection_input) end, fn
        {:ok, %Selection{}} -> true
        {:error, %ArgumentError{}} -> true
        _ -> false
      end)
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

  defp selector_candidate do
    one_of([
      valid_selector_attrs(),
      map(valid_selector_attrs(), &Map.put(&1, :tenant_ids, ["tenant-1", "tenant-1"])),
      map(valid_selector_attrs(), &Map.put(&1, :scope_kinds, ["project", "project"])),
      map(valid_selector_attrs(), &Map.put(&1, :default?, "true")),
      map(valid_selector_attrs(), &Map.put(&1, :extensions, %{"bad" => {:tuple, 1}}))
    ])
  end

  defp policy_pack_candidate do
    one_of([
      valid_policy_pack_attrs(),
      map(valid_policy_pack_attrs(), &put_in(&1, [:selector, :tenant_ids], ["tenant-1", "tenant-1"])),
      map(valid_policy_pack_attrs(), &put_in(&1, [:profiles, :boundary_class], "   ")),
      map(valid_policy_pack_attrs(), &put_in(&1, [:rejection_policy, :extensions], %{"bad" => {:tuple, 1}})),
      map(valid_policy_pack_attrs(), &Map.put(&1, :priority, -1))
    ])
  end

  defp policy_pack_list_candidate do
    one_of([
      list_of(valid_policy_pack_attrs(), min_length: 1, max_length: 4),
      map(list_of(valid_policy_pack_attrs(), min_length: 1, max_length: 4), fn packs ->
        packs ++ [default_pack_attrs()]
      end),
      map(list_of(valid_policy_pack_attrs(), min_length: 1, max_length: 3), fn packs ->
        packs ++ [Map.put(default_pack_attrs(), :selector, %{default?: true})]
      end),
      map(list_of(valid_policy_pack_attrs(), min_length: 1, max_length: 3), fn packs ->
        packs ++ [Map.put(default_pack_attrs(), :extensions, %{"bad" => {:tuple, 1}})]
      end)
    ])
  end

  defp selection_input_candidate do
    one_of([
      valid_selection_input(),
      map(valid_selection_input(), &Map.delete(&1, :tenant_id)),
      map(valid_selection_input(), &Map.put(&1, :scope_kind, 7)),
      map(valid_selection_input(), &Map.put(&1, :environment, "   ")),
      map(valid_selection_input(), &Map.put(&1, :policy_epoch, -1))
    ])
  end

  defp valid_policy_pack_attrs do
    gen all(
          pack_id <- identifier("pack"),
          policy_version <- identifier("policy"),
          policy_epoch <- integer(0..10),
          priority <- integer(0..50),
          tenant_id <- identifier("tenant"),
          scope_kind <- member_of(["project", "workspace"]),
          environment <- member_of(["prod", "dev", "staging"]),
          extensions <- json_object(1)
        ) do
      %{
        pack_id: pack_id,
        policy_version: policy_version,
        policy_epoch: policy_epoch,
        priority: priority,
        selector: %{
          tenant_ids: [tenant_id],
          scope_kinds: [scope_kind],
          environments: [environment],
          default?: false,
          extensions: %{}
        },
        profiles: %{
          trust_profile: "trusted_operator",
          approval_profile: "approval_required",
          egress_profile: "restricted",
          workspace_profile: "project_workspace",
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
        extensions: extensions
      }
    end
  end

  defp default_pack_attrs do
    %{
      pack_id: "default",
      policy_version: "policy-2026-04-10",
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
        approval_profile: "standard_approval",
        egress_profile: "restricted",
        workspace_profile: "default_workspace",
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

  defp valid_selector_attrs do
    gen all(
          tenant_id <- identifier("tenant"),
          scope_kind <- member_of(["project", "workspace"]),
          environment <- member_of(["prod", "dev"]),
          default? <- boolean(),
          extensions <- json_object(1)
        ) do
      %{
        tenant_ids: if(default?, do: [], else: [tenant_id]),
        scope_kinds: if(default?, do: [], else: [scope_kind]),
        environments: if(default?, do: [], else: [environment]),
        default?: default?,
        extensions: extensions
      }
    end
  end

  defp valid_selection_input do
    gen all(
          tenant_id <- identifier("tenant"),
          scope_kind <- member_of(["project", "workspace"]),
          environment <- member_of(["prod", "dev"]),
          include_policy_epoch? <- boolean(),
          policy_epoch <- integer(0..10)
        ) do
      attrs = %{tenant_id: tenant_id, scope_kind: scope_kind, environment: environment}

      if include_policy_epoch? do
        Map.put(attrs, :policy_epoch, policy_epoch)
      else
        attrs
      end
    end
  end

  defp identifier(prefix) do
    map(string(:alphanumeric, min_length: 1, max_length: 24), fn suffix ->
      "#{prefix}-#{suffix}"
    end)
  end

  defp json_object(depth) do
    map_of(json_key(), json_value(depth), max_length: 3)
  end

  defp json_value(0) do
    one_of([
      constant(nil),
      boolean(),
      integer(-10..10),
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
