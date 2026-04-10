defmodule Citadel.ContractCore.CanonicalJson do
  @moduledoc """
  Wave 1 placeholder for the RFC 8785 / JCS boundary.

  The packet requires `DecisionHash` ownership to flow through a canonical JSON
  helper surface instead of relying on implementation-defined map ordering.
  """

  @spec encoder_module() :: module()
  def encoder_module, do: Jcs
end
