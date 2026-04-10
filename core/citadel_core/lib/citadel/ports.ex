defmodule Citadel.Ports.InvocationSink do
  @moduledoc """
  Host-local invocation seam consumed by runtime after commit.
  """

  alias Citadel.ActionOutboxEntry
  alias Citadel.InvocationRequest

  @callback submit_invocation(InvocationRequest.t(), ActionOutboxEntry.t()) ::
              {:ok, String.t()} | {:error, atom()}
end

defmodule Citadel.Ports.RuntimeQuery do
  @moduledoc """
  Rehydrates durable lower truth into normalized Citadel read models.
  """

  alias Citadel.BoundarySessionDescriptor.V1
  alias Citadel.RuntimeObservation

  @callback fetch_runtime_observation(map()) ::
              {:ok, RuntimeObservation.t()} | {:error, atom()}

  @callback fetch_boundary_session(map()) ::
              {:ok, V1.t()} | {:error, atom()}
end

defmodule Citadel.Ports.SignalSource do
  @moduledoc """
  Normalizes runtime signals into `Citadel.RuntimeObservation`.
  """

  alias Citadel.RuntimeObservation

  @callback normalize_signal(term()) :: {:ok, RuntimeObservation.t()} | {:error, atom()}
end

defmodule Citadel.Ports.BoundaryLifecycle do
  @moduledoc """
  Projects boundary intent and normalizes boundary lifecycle facts.
  """

  alias Citadel.AttachGrant.V1
  alias Citadel.BoundaryIntent
  alias Citadel.BoundaryLeaseView
  alias Citadel.BoundarySessionDescriptor.V1, as: BoundarySessionDescriptorV1

  @callback submit_boundary_intent(BoundaryIntent.t(), map()) ::
              {:ok, String.t()} | {:error, atom()}

  @callback normalize_boundary_session(term()) ::
              {:ok, BoundarySessionDescriptorV1.t()} | {:error, atom()}

  @callback normalize_attach_grant(term()) :: {:ok, V1.t()} | {:error, atom()}

  @callback normalize_boundary_lease(term()) ::
              {:ok, BoundaryLeaseView.t()} | {:error, atom()}
end

defmodule Citadel.Ports.ProjectionSink do
  @moduledoc """
  Northbound publication seam for review and derived-state packets.
  """

  alias Citadel.ActionOutboxEntry
  alias Jido.Integration.V2.DerivedStateAttachment
  alias Jido.Integration.V2.ReviewProjection

  @callback publish_review_projection(ReviewProjection.t(), ActionOutboxEntry.t()) ::
              {:ok, String.t()} | {:error, atom()}

  @callback publish_derived_state_attachment(DerivedStateAttachment.t(), ActionOutboxEntry.t()) ::
              {:ok, String.t()} | {:error, atom()}
end

defmodule Citadel.Ports.Trace do
  @moduledoc """
  Frozen minimum trace publication seam.
  """

  alias Citadel.TraceEnvelope

  @callback publish_trace(TraceEnvelope.t()) :: :ok | {:error, atom()}

  @optional_callbacks publish_traces: 1
  @callback publish_traces([TraceEnvelope.t()]) :: :ok | {:error, atom()}
end

defmodule Citadel.Ports.Memory do
  @moduledoc """
  Advisory memory seam keyed lexically by `memory_id`.
  """

  alias Citadel.MemoryRecord

  @callback put_memory_record(MemoryRecord.t()) ::
              {:ok, %{write_guarantee: :stable_put_by_id | :best_effort}} | {:error, atom()}

  @callback get_memory_record(String.t(), keyword()) ::
              {:ok, MemoryRecord.t() | nil} | {:error, atom()}

  @callback rank_memory_records(keyword()) ::
              {:ok, [MemoryRecord.t()]} | {:error, atom()}
end

defmodule Citadel.Ports.Clock do
  @moduledoc """
  Small local clock capability used by runtime owners and adapters.
  """

  @callback utc_now() :: DateTime.t()
end

defmodule Citadel.Ports.Id do
  @moduledoc """
  Small bounded local id capability.
  """

  @callback new_id(atom()) :: {:ok, String.t()} | {:error, atom()}
end

defmodule Citadel.Ports.IntentResolver do
  @moduledoc """
  Optional host-facing structured ingress resolver above the kernel.
  """

  @callback resolve_intent(term()) :: {:ok, term()} | {:error, term()}
end
