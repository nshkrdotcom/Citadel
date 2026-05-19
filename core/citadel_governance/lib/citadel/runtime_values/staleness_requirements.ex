defmodule Citadel.StalenessRequirements do
  @moduledoc """
  Explicit replay-safe stale-check contract for one persisted action.
  """

  alias Citadel.ContractCore.Value

  @schema [
    snapshot_seq: :non_neg_integer,
    policy_epoch: :non_neg_integer,
    topology_epoch: :non_neg_integer,
    scope_catalog_epoch: :non_neg_integer,
    service_admission_epoch: :non_neg_integer,
    project_binding_epoch: :non_neg_integer,
    boundary_epoch: :non_neg_integer,
    required_binding_id: :string,
    required_boundary_ref: :string,
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          snapshot_seq: non_neg_integer() | nil,
          policy_epoch: non_neg_integer() | nil,
          topology_epoch: non_neg_integer() | nil,
          scope_catalog_epoch: non_neg_integer() | nil,
          service_admission_epoch: non_neg_integer() | nil,
          project_binding_epoch: non_neg_integer() | nil,
          boundary_epoch: non_neg_integer() | nil,
          required_binding_id: String.t() | nil,
          required_boundary_ref: String.t() | nil,
          extensions: map()
        }

  @enforce_keys []
  defstruct snapshot_seq: nil,
            policy_epoch: nil,
            topology_epoch: nil,
            scope_catalog_epoch: nil,
            service_admission_epoch: nil,
            project_binding_epoch: nil,
            boundary_epoch: nil,
            required_binding_id: nil,
            required_boundary_ref: nil,
            extensions: %{}

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.StalenessRequirements", @fields)

    requirements = %__MODULE__{
      snapshot_seq:
        Value.optional(
          attrs,
          :snapshot_seq,
          "Citadel.StalenessRequirements",
          fn value ->
            Value.non_neg_integer!(value, "Citadel.StalenessRequirements.snapshot_seq")
          end,
          nil
        ),
      policy_epoch:
        Value.optional(
          attrs,
          :policy_epoch,
          "Citadel.StalenessRequirements",
          fn value ->
            Value.non_neg_integer!(value, "Citadel.StalenessRequirements.policy_epoch")
          end,
          nil
        ),
      topology_epoch:
        Value.optional(
          attrs,
          :topology_epoch,
          "Citadel.StalenessRequirements",
          fn value ->
            Value.non_neg_integer!(value, "Citadel.StalenessRequirements.topology_epoch")
          end,
          nil
        ),
      scope_catalog_epoch:
        Value.optional(
          attrs,
          :scope_catalog_epoch,
          "Citadel.StalenessRequirements",
          fn value ->
            Value.non_neg_integer!(value, "Citadel.StalenessRequirements.scope_catalog_epoch")
          end,
          nil
        ),
      service_admission_epoch:
        Value.optional(
          attrs,
          :service_admission_epoch,
          "Citadel.StalenessRequirements",
          fn value ->
            Value.non_neg_integer!(value, "Citadel.StalenessRequirements.service_admission_epoch")
          end,
          nil
        ),
      project_binding_epoch:
        Value.optional(
          attrs,
          :project_binding_epoch,
          "Citadel.StalenessRequirements",
          fn value ->
            Value.non_neg_integer!(value, "Citadel.StalenessRequirements.project_binding_epoch")
          end,
          nil
        ),
      boundary_epoch:
        Value.optional(
          attrs,
          :boundary_epoch,
          "Citadel.StalenessRequirements",
          fn value ->
            Value.non_neg_integer!(value, "Citadel.StalenessRequirements.boundary_epoch")
          end,
          nil
        ),
      required_binding_id:
        Value.optional(
          attrs,
          :required_binding_id,
          "Citadel.StalenessRequirements",
          fn value ->
            Value.string!(value, "Citadel.StalenessRequirements.required_binding_id")
          end,
          nil
        ),
      required_boundary_ref:
        Value.optional(
          attrs,
          :required_boundary_ref,
          "Citadel.StalenessRequirements",
          fn value ->
            Value.string!(value, "Citadel.StalenessRequirements.required_boundary_ref")
          end,
          nil
        ),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.StalenessRequirements",
          fn value ->
            Value.json_object!(value, "Citadel.StalenessRequirements.extensions")
          end,
          %{}
        )
    }

    meaningful =
      Map.take(requirements, [
        :policy_epoch,
        :topology_epoch,
        :scope_catalog_epoch,
        :service_admission_epoch,
        :project_binding_epoch,
        :boundary_epoch,
        :required_binding_id,
        :required_boundary_ref
      ])
      |> Map.values()
      |> Enum.reject(&is_nil/1)

    if meaningful == [] do
      raise ArgumentError,
            "Citadel.StalenessRequirements must carry an explicit epoch, binding, or boundary comparison"
    end

    requirements
  end

  def dump(%__MODULE__{} = requirements) do
    %{
      snapshot_seq: requirements.snapshot_seq,
      policy_epoch: requirements.policy_epoch,
      topology_epoch: requirements.topology_epoch,
      scope_catalog_epoch: requirements.scope_catalog_epoch,
      service_admission_epoch: requirements.service_admission_epoch,
      project_binding_epoch: requirements.project_binding_epoch,
      boundary_epoch: requirements.boundary_epoch,
      required_binding_id: requirements.required_binding_id,
      required_boundary_ref: requirements.required_boundary_ref,
      extensions: requirements.extensions
    }
  end
end
