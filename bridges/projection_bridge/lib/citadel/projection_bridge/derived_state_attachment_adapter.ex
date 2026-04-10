defmodule Citadel.ProjectionBridge.DerivedStateAttachmentAdapter do
  @moduledoc """
  Isolates `DerivedStateAttachment` contract-shape evolution at the bridge edge.
  """

  alias Jido.Integration.V2.DerivedStateAttachment

  @spec normalize!(DerivedStateAttachment.t() | map() | keyword()) :: DerivedStateAttachment.t()
  def normalize!(%DerivedStateAttachment{} = attachment), do: DerivedStateAttachment.new!(attachment)
  def normalize!(attrs), do: DerivedStateAttachment.new!(attrs)
end
