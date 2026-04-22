defmodule Citadel.BridgeSnapshotCacheAuditTest do
  use ExUnit.Case, async: true

  @bridge_source_glob "bridges/*/lib/**/*.ex"
  @forbidden_snapshot_cache_patterns [
    "Citadel.Kernel.KernelSnapshot",
    "KernelSnapshot.",
    ":persistent_term",
    ":ets"
  ]

  test "bridge libraries do not keep duplicate Citadel snapshot caches" do
    offenders =
      @bridge_source_glob
      |> Path.wildcard()
      |> Enum.flat_map(fn path ->
        source = File.read!(path)

        @forbidden_snapshot_cache_patterns
        |> Enum.filter(&String.contains?(source, &1))
        |> Enum.map(&{path, &1})
      end)

    assert offenders == [],
           "bridge libraries must use Citadel-owned snapshot APIs/read surfaces instead of duplicate local caches: #{inspect(offenders)}"
  end
end
