defmodule Citadel.Build.DependencyResolver do
  @moduledoc false

  @default_jido_integration_contracts_path "/home/home/p/g/n/jido_integration/core/contracts"
  @published_jido_integration_contracts_requirement "~> 0.1.0"

  def jido_integration_v2_contracts(opts \\ []) do
    case jido_integration_v2_contracts_source() do
      {:path, path} ->
        {:jido_integration_v2_contracts, Keyword.merge([path: path, override: true], opts)}

      {:hex, requirement} ->
        {:jido_integration_v2_contracts, requirement, opts}
    end
  end

  def jido_integration_v2_contracts_source do
    case resolve_contracts_path() do
      nil -> {:hex, @published_jido_integration_contracts_requirement}
      path -> {:path, path}
    end
  end

  def published_jido_integration_v2_contracts_requirement do
    @published_jido_integration_contracts_requirement
  end

  defp resolve_contracts_path do
    [
      explicit_contracts_path(),
      jido_integration_root_path(),
      @default_jido_integration_contracts_path
    ]
    |> Enum.find_value(&existing_path/1)
  end

  defp explicit_contracts_path do
    case System.get_env("CITADEL_JIDO_INTEGRATION_CONTRACTS_PATH") do
      nil -> nil
      value when value in ["", "0", "false", "disabled"] -> nil
      value -> value
    end
  end

  defp jido_integration_root_path do
    case System.get_env("JIDO_INTEGRATION_PATH") do
      nil -> nil
      value when value in ["", "0", "false", "disabled"] -> nil
      value -> Path.join(value, "core/contracts")
    end
  end

  defp existing_path(nil), do: nil

  defp existing_path(path) do
    expanded = Path.expand(path)

    if File.dir?(expanded) do
      expanded
    else
      nil
    end
  end
end
