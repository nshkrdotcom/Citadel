defmodule Citadel.AuthorityPacketV2 do
  @moduledoc """
  Public Phase 4 module name for the canonical authority packet v2 contract.
  """

  alias Citadel.AuthorityContract.AuthorityPacket.V2

  defdelegate packet_name(), to: V2
  defdelegate contract_version(), to: V2
  defdelegate required_fields(), to: V2
  defdelegate new(attrs), to: V2
  defdelegate new!(attrs), to: V2
  defdelegate dump(packet), to: V2
  defdelegate put_hashes!(attrs), to: V2
  defdelegate hashes_valid?(packet), to: V2
end

defmodule Citadel.EnterprisePrecutSupport do
  @moduledoc false

  @spec build(module(), String.t(), [atom()], [atom()], map() | keyword(), keyword()) ::
          {:ok, struct()} | {:error, term()}
  def build(module, contract_name, fields, required_fields, attrs, opts \\ []) do
    with {:ok, attrs} <- normalize_attrs(attrs),
         [] <- missing_required_fields(attrs, required_fields),
         :ok <- validate_enums(attrs, Keyword.get(opts, :enums, [])),
         :ok <- validate_lists(attrs, Keyword.get(opts, :list_fields, [])) do
      {:ok, struct(module, attrs |> Map.take(fields) |> Map.put(:contract_name, contract_name))}
    else
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_attrs(attrs) when is_list(attrs), do: {:ok, Map.new(attrs)}

  defp normalize_attrs(attrs) when is_map(attrs) do
    if Map.has_key?(attrs, :__struct__), do: {:ok, Map.from_struct(attrs)}, else: {:ok, attrs}
  end

  defp normalize_attrs(_attrs), do: {:error, :invalid_attrs}

  defp missing_required_fields(attrs, required_fields) do
    Enum.reject(required_fields, &present?(Map.get(attrs, &1)))
  end

  defp validate_enums(attrs, enum_specs) do
    invalid? =
      Enum.any?(enum_specs, fn {field, allowed} ->
        value = Map.get(attrs, field)
        present?(value) and normalize_enum(value) not in allowed
      end)

    if invalid?, do: {:error, :invalid_enum_field}, else: :ok
  end

  defp validate_lists(attrs, fields) do
    if Enum.all?(fields, &is_list(Map.get(attrs, &1, []))) do
      :ok
    else
      {:error, :invalid_list_field}
    end
  end

  defp normalize_enum(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_enum(value), do: value

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value) when is_list(value), do: value != []
  defp present?(value), do: not is_nil(value)
end

defmodule Citadel.PermissionDecisionV1 do
  @moduledoc """
  Enterprise pre-cut permission decision packet for accepted and denied actions.
  """

  alias Citadel.EnterprisePrecutSupport

  @contract_name "Citadel.PermissionDecisionV1.v1"
  @results ["allow", "deny", "abstain", "stale_policy", "insufficient_scope"]
  @fields [
    :contract_name,
    :decision_id,
    :decision_version,
    :authority_packet_ref,
    :tenant_ref,
    :actor_ref,
    :resource_ref,
    :action_name,
    :result,
    :rejection_class,
    :policy_bundle_ref,
    :policy_revision,
    :input_hash,
    :decision_hash,
    :evidence_refs,
    :trace_id,
    :decided_at
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, term()}
  def new(attrs) do
    EnterprisePrecutSupport.build(
      __MODULE__,
      @contract_name,
      @fields,
      [
        :decision_id,
        :decision_version,
        :authority_packet_ref,
        :tenant_ref,
        :actor_ref,
        :resource_ref,
        :action_name,
        :result,
        :policy_bundle_ref,
        :policy_revision,
        :input_hash,
        :decision_hash,
        :evidence_refs,
        :trace_id,
        :decided_at
      ],
      attrs,
      enums: [result: @results],
      list_fields: [:evidence_refs]
    )
  end
end

defmodule Citadel.RejectionClass do
  @moduledoc """
  Closed Phase 4 rejection class vocabulary used by permission decisions.
  """

  @classes [
    "missing_required_field",
    "wrong_tenant",
    "missing_authority",
    "unauthorized_action",
    "stale_revision",
    "stale_lease",
    "duplicate_command",
    "duplicate_side_effect",
    "lower_scope_denied",
    "attach_denied",
    "semantic_provenance_missing",
    "product_bypass_blocked"
  ]

  @spec all() :: [String.t()]
  def all, do: @classes

  @spec known?(String.t() | atom()) :: boolean()
  def known?(value) when is_atom(value), do: value |> Atom.to_string() |> known?()
  def known?(value) when is_binary(value), do: value in @classes
  def known?(_value), do: false
end

defmodule Citadel.PolicyEvidenceRef do
  @moduledoc """
  Public-safe evidence reference for policy inputs used by Citadel decisions.
  """

  alias Citadel.EnterprisePrecutSupport

  @fields [
    :contract_name,
    :evidence_ref,
    :tenant_ref,
    :policy_bundle_ref,
    :policy_revision,
    :trace_id,
    :input_hash
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, term()}
  def new(attrs) do
    EnterprisePrecutSupport.build(
      __MODULE__,
      "Citadel.PolicyEvidenceRef.v1",
      @fields,
      [:evidence_ref, :tenant_ref, :policy_bundle_ref, :policy_revision, :trace_id],
      attrs
    )
  end
end

defmodule Citadel.OperatorWorkflowSignalAuthorityV1 do
  @moduledoc """
  Enterprise pre-cut authority decision for operator workflow signals.

  This contract authorizes or denies cancel, pause, resume, retry, and replan
  signals before Mezzanine commits a local signal receipt and outbox row.
  """

  alias Citadel.EnterprisePrecutSupport

  @contract_name "Citadel.OperatorWorkflowSignalAuthority.v1"
  @results [
    "allow",
    "deny",
    "stale_policy",
    "insufficient_scope",
    "unregistered_signal"
  ]
  @fields [
    :contract_name,
    :decision_id,
    :tenant_ref,
    :installation_ref,
    :workspace_ref,
    :project_ref,
    :environment_ref,
    :principal_ref,
    :system_actor_ref,
    :operator_ref,
    :resource_ref,
    :workflow_id,
    :workflow_run_id,
    :signal_id,
    :signal_name,
    :signal_version,
    :signal_effect,
    :requested_action,
    :result,
    :rejection_class,
    :authority_packet_ref,
    :permission_decision_ref,
    :policy_bundle_ref,
    :policy_revision,
    :idempotency_key,
    :trace_id,
    :correlation_id,
    :release_manifest_ref,
    :decided_at,
    :evidence_refs
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, term()}
  def new(attrs) do
    EnterprisePrecutSupport.build(
      __MODULE__,
      @contract_name,
      @fields,
      [
        :decision_id,
        :tenant_ref,
        :installation_ref,
        :principal_ref,
        :operator_ref,
        :resource_ref,
        :workflow_id,
        :signal_id,
        :signal_name,
        :signal_version,
        :signal_effect,
        :requested_action,
        :result,
        :authority_packet_ref,
        :permission_decision_ref,
        :policy_bundle_ref,
        :policy_revision,
        :idempotency_key,
        :trace_id,
        :correlation_id,
        :release_manifest_ref,
        :decided_at,
        :evidence_refs
      ],
      attrs,
      enums: [result: @results],
      list_fields: [:evidence_refs]
    )
  end
end
