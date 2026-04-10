defmodule Citadel.ContractCore.CanonicalJsonTest do
  use ExUnit.Case, async: true

  alias Citadel.ContractCore
  alias Citadel.ContractCore.CanonicalJson

  test "tracks the packet-pinned JCS dependency boundary" do
    assert CanonicalJson.encoder_module() == Jcs
    assert ContractCore.manifest().external_dependencies == [:jcs]
  end
end
