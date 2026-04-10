defmodule Citadel.PolicyPacks do
  @moduledoc """
  Packet-aligned ownership surface for `core/policy_packs`.
  """

  @manifest %{
    package: :citadel_policy_packs,
    layer: :core,
    status: :wave_1_skeleton,
    owns: [:policy_pack_definitions, :profile_selection, :epoch_inputs],
    internal_dependencies: [:citadel_contract_core],
    external_dependencies: []
  }

  @spec selection_inputs() :: [atom()]
  def selection_inputs, do: [:tenant_id, :scope_selector, :policy_epoch]

  @spec manifest() :: map()
  def manifest, do: @manifest
end
