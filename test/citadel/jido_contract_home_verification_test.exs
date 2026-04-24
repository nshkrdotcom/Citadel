defmodule Citadel.JidoContractHomeVerificationTest do
  use ExUnit.Case, async: true

  @repo_root Path.expand("../..", __DIR__)
  @local_slice Path.join(@repo_root, "core/jido_integration_contracts/lib/jido/integration/v2")
  @upstream_slice Path.expand(
                    "../jido_integration/core/contracts/lib/jido/integration/v2",
                    @repo_root
                  )

  test "vendored Jido.Integration.V2 modules are an upstream-equivalent slice" do
    assert File.dir?(@upstream_slice)

    local_files = contract_files(@local_slice)
    assert local_files != []

    assert [] = missing_upstream_files(local_files)
    assert [] = divergent_files(local_files)
  end

  defp contract_files(root) do
    root
    |> Path.join("**/*.ex")
    |> Path.wildcard()
    |> Enum.map(&Path.relative_to(&1, root))
    |> Enum.sort()
  end

  defp missing_upstream_files(local_files) do
    Enum.reject(local_files, fn relative ->
      File.exists?(Path.join(@upstream_slice, relative))
    end)
  end

  defp divergent_files(local_files) do
    Enum.reject(local_files, fn relative ->
      local = Path.join(@local_slice, relative)
      upstream = Path.join(@upstream_slice, relative)

      File.read!(local) == File.read!(upstream)
    end)
  end
end
