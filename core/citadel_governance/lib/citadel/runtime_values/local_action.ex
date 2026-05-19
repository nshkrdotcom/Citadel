defmodule Citadel.LocalAction do
  @moduledoc """
  Deferred post-commit local action.
  """

  alias Citadel.ContractCore.Value

  @schema [
    action_kind: :string,
    payload: {:map, :json},
    extensions: {:map, :json}
  ]
  @fields Keyword.keys(@schema)

  @type t :: %__MODULE__{
          action_kind: String.t(),
          payload: map(),
          extensions: map()
        }

  @enforce_keys @fields
  defstruct @fields

  def schema, do: @schema

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.LocalAction", @fields)

    %__MODULE__{
      action_kind:
        Value.required(attrs, :action_kind, "Citadel.LocalAction", fn value ->
          Value.string!(value, "Citadel.LocalAction.action_kind")
        end),
      payload:
        Value.required(attrs, :payload, "Citadel.LocalAction", fn value ->
          Value.json_object!(value, "Citadel.LocalAction.payload")
        end),
      extensions:
        Value.optional(
          attrs,
          :extensions,
          "Citadel.LocalAction",
          fn value ->
            Value.json_object!(value, "Citadel.LocalAction.extensions")
          end,
          %{}
        )
    }
  end

  def dump(%__MODULE__{} = action) do
    %{
      action_kind: action.action_kind,
      payload: action.payload,
      extensions: action.extensions
    }
  end
end
