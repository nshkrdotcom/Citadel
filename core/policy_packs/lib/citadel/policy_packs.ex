defmodule Citadel.PolicyPacks.Selector do
  @moduledoc """
  Explicit policy-pack selector inputs.
  """

  alias Citadel.ContractCore.Value

  @schema [
    tenant_ids: {:list, :string},
    scope_kinds: {:list, :string},
    environments: {:list, :string},
    default?: :boolean,
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          tenant_ids: [String.t()],
          scope_kinds: [String.t()],
          environments: [String.t()],
          default?: boolean(),
          extensions: map()
        }

  @enforce_keys @fields
  defstruct @fields

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.PolicyPacks.Selector", @fields)

    %__MODULE__{
      tenant_ids:
        Value.optional(
          attrs,
          :tenant_ids,
          "Citadel.PolicyPacks.Selector",
          fn value ->
            Value.unique_strings!(value, "Citadel.PolicyPacks.Selector.tenant_ids")
          end,
          []
        ),
      scope_kinds:
        Value.optional(
          attrs,
          :scope_kinds,
          "Citadel.PolicyPacks.Selector",
          fn value ->
            Value.unique_strings!(value, "Citadel.PolicyPacks.Selector.scope_kinds")
          end,
          []
        ),
      environments:
        Value.optional(
          attrs,
          :environments,
          "Citadel.PolicyPacks.Selector",
          fn value ->
            Value.unique_strings!(value, "Citadel.PolicyPacks.Selector.environments")
          end,
          []
        ),
      default?:
        Value.optional(
          attrs,
          :default?,
          "Citadel.PolicyPacks.Selector",
          fn value ->
            Value.boolean!(value, "Citadel.PolicyPacks.Selector.default?")
          end,
          false
        ),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.PolicyPacks.Selector",
          fn value ->
            Value.json_object!(value, "Citadel.PolicyPacks.Selector.extensions")
          end,
          %{}
        )
    }
  end

  def dump(%__MODULE__{} = selector) do
    %{
      tenant_ids: selector.tenant_ids,
      scope_kinds: selector.scope_kinds,
      environments: selector.environments,
      default?: selector.default?,
      extensions: selector.extensions
    }
  end

  def matches?(%__MODULE__{default?: true}, _attrs), do: true

  def matches?(%__MODULE__{} = selector, attrs) when is_map(attrs) do
    tenant_id = Value.string!(Map.fetch!(attrs, :tenant_id), "policy selection tenant_id")
    scope_kind = Value.string!(Map.fetch!(attrs, :scope_kind), "policy selection scope_kind")

    environment =
      Value.optional_string!(Map.get(attrs, :environment), "policy selection environment")

    match_dimension?(selector.tenant_ids, tenant_id) and
      match_dimension?(selector.scope_kinds, scope_kind) and
      match_dimension?(selector.environments, environment)
  end

  defp match_dimension?([], _value), do: true
  defp match_dimension?(values, value), do: value in values
end

defmodule Citadel.PolicyPacks.Profiles do
  @moduledoc """
  Explicit decision-shaping profiles selected from one policy pack.
  """

  alias Citadel.ContractCore.Value

  @schema [
    trust_profile: :string,
    approval_profile: :string,
    egress_profile: :string,
    workspace_profile: :string,
    resource_profile: :string,
    boundary_class: :string,
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          trust_profile: String.t(),
          approval_profile: String.t(),
          egress_profile: String.t(),
          workspace_profile: String.t(),
          resource_profile: String.t(),
          boundary_class: String.t(),
          extensions: map()
        }

  @enforce_keys @fields
  defstruct @fields

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.PolicyPacks.Profiles", @fields)

    %__MODULE__{
      trust_profile:
        Value.required(attrs, :trust_profile, "Citadel.PolicyPacks.Profiles", fn value ->
          Value.string!(value, "Citadel.PolicyPacks.Profiles.trust_profile")
        end),
      approval_profile:
        Value.required(attrs, :approval_profile, "Citadel.PolicyPacks.Profiles", fn value ->
          Value.string!(value, "Citadel.PolicyPacks.Profiles.approval_profile")
        end),
      egress_profile:
        Value.required(attrs, :egress_profile, "Citadel.PolicyPacks.Profiles", fn value ->
          Value.string!(value, "Citadel.PolicyPacks.Profiles.egress_profile")
        end),
      workspace_profile:
        Value.required(attrs, :workspace_profile, "Citadel.PolicyPacks.Profiles", fn value ->
          Value.string!(value, "Citadel.PolicyPacks.Profiles.workspace_profile")
        end),
      resource_profile:
        Value.required(attrs, :resource_profile, "Citadel.PolicyPacks.Profiles", fn value ->
          Value.string!(value, "Citadel.PolicyPacks.Profiles.resource_profile")
        end),
      boundary_class:
        Value.required(attrs, :boundary_class, "Citadel.PolicyPacks.Profiles", fn value ->
          Value.string!(value, "Citadel.PolicyPacks.Profiles.boundary_class")
        end),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.PolicyPacks.Profiles",
          fn value ->
            Value.json_object!(value, "Citadel.PolicyPacks.Profiles.extensions")
          end,
          %{}
        )
    }
  end

  def dump(%__MODULE__{} = profiles) do
    %{
      trust_profile: profiles.trust_profile,
      approval_profile: profiles.approval_profile,
      egress_profile: profiles.egress_profile,
      workspace_profile: profiles.workspace_profile,
      resource_profile: profiles.resource_profile,
      boundary_class: profiles.boundary_class,
      extensions: profiles.extensions
    }
  end
end

defmodule Citadel.PolicyPacks.RejectionPolicy do
  @moduledoc """
  Pure policy inputs for rejection retryability and publication classification.
  """

  alias Citadel.ContractCore.Value

  @schema [
    denial_audit_reason_codes: {:list, :string},
    derived_state_reason_codes: {:list, :string},
    runtime_change_reason_codes: {:list, :string},
    governance_change_reason_codes: {:list, :string},
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          denial_audit_reason_codes: [String.t()],
          derived_state_reason_codes: [String.t()],
          runtime_change_reason_codes: [String.t()],
          governance_change_reason_codes: [String.t()],
          extensions: map()
        }

  @enforce_keys @fields
  defstruct @fields

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.PolicyPacks.RejectionPolicy", @fields)

    %__MODULE__{
      denial_audit_reason_codes:
        Value.optional(
          attrs,
          :denial_audit_reason_codes,
          "Citadel.PolicyPacks.RejectionPolicy",
          fn value ->
            Value.unique_strings!(
              value,
              "Citadel.PolicyPacks.RejectionPolicy.denial_audit_reason_codes"
            )
          end,
          []
        ),
      derived_state_reason_codes:
        Value.optional(
          attrs,
          :derived_state_reason_codes,
          "Citadel.PolicyPacks.RejectionPolicy",
          fn value ->
            Value.unique_strings!(
              value,
              "Citadel.PolicyPacks.RejectionPolicy.derived_state_reason_codes"
            )
          end,
          []
        ),
      runtime_change_reason_codes:
        Value.optional(
          attrs,
          :runtime_change_reason_codes,
          "Citadel.PolicyPacks.RejectionPolicy",
          fn value ->
            Value.unique_strings!(
              value,
              "Citadel.PolicyPacks.RejectionPolicy.runtime_change_reason_codes"
            )
          end,
          []
        ),
      governance_change_reason_codes:
        Value.optional(
          attrs,
          :governance_change_reason_codes,
          "Citadel.PolicyPacks.RejectionPolicy",
          fn value ->
            Value.unique_strings!(
              value,
              "Citadel.PolicyPacks.RejectionPolicy.governance_change_reason_codes"
            )
          end,
          []
        ),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.PolicyPacks.RejectionPolicy",
          fn value ->
            Value.json_object!(value, "Citadel.PolicyPacks.RejectionPolicy.extensions")
          end,
          %{}
        )
    }
  end

  def dump(%__MODULE__{} = policy) do
    %{
      denial_audit_reason_codes: policy.denial_audit_reason_codes,
      derived_state_reason_codes: policy.derived_state_reason_codes,
      runtime_change_reason_codes: policy.runtime_change_reason_codes,
      governance_change_reason_codes: policy.governance_change_reason_codes,
      extensions: policy.extensions
    }
  end
end

defmodule Citadel.PolicyPacks.PolicyPack do
  @moduledoc """
  One explicit policy pack plus its selector, profile set, and rejection policy.
  """

  alias Citadel.ContractCore.Value
  alias Citadel.PolicyPacks.Profiles
  alias Citadel.PolicyPacks.RejectionPolicy
  alias Citadel.PolicyPacks.Selector

  @schema [
    pack_id: :string,
    policy_version: :string,
    policy_epoch: :non_neg_integer,
    priority: :non_neg_integer,
    selector: {:struct, Selector},
    profiles: {:struct, Profiles},
    rejection_policy: {:struct, RejectionPolicy},
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          pack_id: String.t(),
          policy_version: String.t(),
          policy_epoch: non_neg_integer(),
          priority: non_neg_integer(),
          selector: Selector.t(),
          profiles: Profiles.t(),
          rejection_policy: RejectionPolicy.t(),
          extensions: map()
        }

  @enforce_keys @fields
  defstruct @fields

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.PolicyPacks.PolicyPack", @fields)

    %__MODULE__{
      pack_id:
        Value.required(attrs, :pack_id, "Citadel.PolicyPacks.PolicyPack", fn value ->
          Value.string!(value, "Citadel.PolicyPacks.PolicyPack.pack_id")
        end),
      policy_version:
        Value.required(attrs, :policy_version, "Citadel.PolicyPacks.PolicyPack", fn value ->
          Value.string!(value, "Citadel.PolicyPacks.PolicyPack.policy_version")
        end),
      policy_epoch:
        Value.required(attrs, :policy_epoch, "Citadel.PolicyPacks.PolicyPack", fn value ->
          Value.non_neg_integer!(value, "Citadel.PolicyPacks.PolicyPack.policy_epoch")
        end),
      priority:
        Value.optional(
          attrs,
          :priority,
          "Citadel.PolicyPacks.PolicyPack",
          fn value ->
            Value.non_neg_integer!(value, "Citadel.PolicyPacks.PolicyPack.priority")
          end,
          0
        ),
      selector:
        Value.required(attrs, :selector, "Citadel.PolicyPacks.PolicyPack", fn value ->
          Value.module!(value, Selector, "Citadel.PolicyPacks.PolicyPack.selector")
        end),
      profiles:
        Value.required(attrs, :profiles, "Citadel.PolicyPacks.PolicyPack", fn value ->
          Value.module!(value, Profiles, "Citadel.PolicyPacks.PolicyPack.profiles")
        end),
      rejection_policy:
        Value.required(attrs, :rejection_policy, "Citadel.PolicyPacks.PolicyPack", fn value ->
          Value.module!(value, RejectionPolicy, "Citadel.PolicyPacks.PolicyPack.rejection_policy")
        end),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.PolicyPacks.PolicyPack",
          fn value ->
            Value.json_object!(value, "Citadel.PolicyPacks.PolicyPack.extensions")
          end,
          %{}
        )
    }
  end

  def dump(%__MODULE__{} = pack) do
    %{
      pack_id: pack.pack_id,
      policy_version: pack.policy_version,
      policy_epoch: pack.policy_epoch,
      priority: pack.priority,
      selector: Selector.dump(pack.selector),
      profiles: Profiles.dump(pack.profiles),
      rejection_policy: RejectionPolicy.dump(pack.rejection_policy),
      extensions: pack.extensions
    }
  end

  def matches?(%__MODULE__{} = pack, attrs), do: Selector.matches?(pack.selector, attrs)
end

defmodule Citadel.PolicyPacks.Selection do
  @moduledoc """
  Deterministic output of policy-pack profile selection.
  """

  alias Citadel.ContractCore.Value
  alias Citadel.PolicyPacks.Profiles
  alias Citadel.PolicyPacks.RejectionPolicy

  @schema [
    pack_id: :string,
    policy_version: :string,
    policy_epoch: :non_neg_integer,
    priority: :non_neg_integer,
    profiles: {:struct, Profiles},
    rejection_policy: {:struct, RejectionPolicy},
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          pack_id: String.t(),
          policy_version: String.t(),
          policy_epoch: non_neg_integer(),
          priority: non_neg_integer(),
          profiles: Profiles.t(),
          rejection_policy: RejectionPolicy.t(),
          extensions: map()
        }

  @enforce_keys @fields
  defstruct @fields

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.PolicyPacks.Selection", @fields)

    %__MODULE__{
      pack_id:
        Value.required(attrs, :pack_id, "Citadel.PolicyPacks.Selection", fn value ->
          Value.string!(value, "Citadel.PolicyPacks.Selection.pack_id")
        end),
      policy_version:
        Value.required(attrs, :policy_version, "Citadel.PolicyPacks.Selection", fn value ->
          Value.string!(value, "Citadel.PolicyPacks.Selection.policy_version")
        end),
      policy_epoch:
        Value.required(attrs, :policy_epoch, "Citadel.PolicyPacks.Selection", fn value ->
          Value.non_neg_integer!(value, "Citadel.PolicyPacks.Selection.policy_epoch")
        end),
      priority:
        Value.required(attrs, :priority, "Citadel.PolicyPacks.Selection", fn value ->
          Value.non_neg_integer!(value, "Citadel.PolicyPacks.Selection.priority")
        end),
      profiles:
        Value.required(attrs, :profiles, "Citadel.PolicyPacks.Selection", fn value ->
          Value.module!(value, Profiles, "Citadel.PolicyPacks.Selection.profiles")
        end),
      rejection_policy:
        Value.required(attrs, :rejection_policy, "Citadel.PolicyPacks.Selection", fn value ->
          Value.module!(value, RejectionPolicy, "Citadel.PolicyPacks.Selection.rejection_policy")
        end),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.PolicyPacks.Selection",
          fn value ->
            Value.json_object!(value, "Citadel.PolicyPacks.Selection.extensions")
          end,
          %{}
        )
    }
  end

  def dump(%__MODULE__{} = selection) do
    %{
      pack_id: selection.pack_id,
      policy_version: selection.policy_version,
      policy_epoch: selection.policy_epoch,
      priority: selection.priority,
      profiles: Profiles.dump(selection.profiles),
      rejection_policy: RejectionPolicy.dump(selection.rejection_policy),
      extensions: selection.extensions
    }
  end
end

defmodule Citadel.PolicyPacks do
  @moduledoc """
  Explicit policy-pack definitions and deterministic profile selection.
  """

  alias Citadel.ContractCore.Value
  alias Citadel.PolicyPacks.PolicyPack
  alias Citadel.PolicyPacks.Selection

  @manifest %{
    package: :citadel_policy_packs,
    layer: :core,
    status: :wave_3_policy_packs_frozen,
    owns: [
      :policy_pack_values,
      :profile_selection,
      :rejection_policy_inputs,
      :policy_epoch_inputs
    ],
    internal_dependencies: [:citadel_contract_core],
    external_dependencies: []
  }

  @selection_input_fields [:tenant_id, :scope_kind, :environment, :policy_epoch]

  @type selection_input :: %{
          required(:tenant_id) => String.t(),
          required(:scope_kind) => String.t(),
          optional(:environment) => String.t(),
          optional(:policy_epoch) => non_neg_integer()
        }

  @spec selection_inputs() :: [atom()]
  def selection_inputs, do: @selection_input_fields

  @spec manifest() :: map()
  def manifest, do: @manifest

  @spec select_profile!([PolicyPack.t() | map()], map() | keyword()) :: Selection.t()
  def select_profile!(packs, attrs) when is_list(packs) do
    attrs = normalize_selection_inputs!(attrs)

    selected_pack =
      packs
      |> Enum.map(&PolicyPack.new!/1)
      |> Enum.filter(&PolicyPack.matches?(&1, attrs))
      |> Enum.sort_by(&{-&1.priority, &1.pack_id})
      |> List.first()

    case selected_pack do
      nil ->
        raise ArgumentError,
              "no policy pack matched tenant_id=#{inspect(attrs.tenant_id)} scope_kind=#{inspect(attrs.scope_kind)} environment=#{inspect(attrs.environment)}"

      %PolicyPack{} = pack ->
        Selection.new!(%{
          pack_id: pack.pack_id,
          policy_version: pack.policy_version,
          policy_epoch: pack.policy_epoch,
          priority: pack.priority,
          profiles: pack.profiles,
          rejection_policy: pack.rejection_policy,
          extensions: pack.extensions
        })
    end
  end

  @spec select_profile([PolicyPack.t() | map()], map() | keyword()) ::
          {:ok, Selection.t()} | {:error, Exception.t()}
  def select_profile(packs, attrs) do
    {:ok, select_profile!(packs, attrs)}
  rescue
    error in ArgumentError -> {:error, error}
  end

  @spec stable_selection_ordering() :: :priority_desc_then_pack_id_asc
  def stable_selection_ordering, do: :priority_desc_then_pack_id_asc

  defp normalize_selection_inputs!(attrs) do
    attrs =
      Value.normalize_attrs!(
        attrs,
        "Citadel.PolicyPacks selection input",
        @selection_input_fields
      )

    %{
      tenant_id:
        Value.required(attrs, :tenant_id, "Citadel.PolicyPacks selection input", fn value ->
          Value.string!(value, "Citadel.PolicyPacks selection input.tenant_id")
        end),
      scope_kind:
        Value.required(attrs, :scope_kind, "Citadel.PolicyPacks selection input", fn value ->
          Value.string!(value, "Citadel.PolicyPacks selection input.scope_kind")
        end),
      environment:
        Value.optional(
          attrs,
          :environment,
          "Citadel.PolicyPacks selection input",
          fn value ->
            Value.string!(value, "Citadel.PolicyPacks selection input.environment")
          end,
          nil
        ),
      policy_epoch:
        Value.optional(
          attrs,
          :policy_epoch,
          "Citadel.PolicyPacks selection input",
          fn value ->
            Value.non_neg_integer!(value, "Citadel.PolicyPacks selection input.policy_epoch")
          end,
          nil
        )
    }
  end
end
