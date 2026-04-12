defmodule Citadel.Ports.InvocationSink do
  @moduledoc """
  Host-local invocation seam consumed by runtime after commit.
  """

  alias Citadel.ActionOutboxEntry
  alias Citadel.InvocationRequest.V2, as: InvocationRequestV2

  @type submission_result :: {:ok, String.t()} | {:error, atom()}

  @callback submit_invocation(InvocationRequestV2.t(), ActionOutboxEntry.t()) ::
              submission_result()
end

defmodule Citadel.Ports.RuntimeQuery do
  @moduledoc """
  Rehydrates durable lower truth into normalized Citadel read models.
  """

  alias Citadel.BoundarySessionDescriptor.V1
  alias Citadel.RuntimeObservation

  @type runtime_observation_query :: %{
          required(:downstream_scope) => String.t(),
          optional(:request_id) => String.t(),
          optional(:session_id) => String.t(),
          optional(:signal_id) => String.t(),
          optional(:signal_cursor) => String.t(),
          optional(:runtime_ref_id) => String.t()
        }
  @type boundary_session_query :: %{
          required(:downstream_scope) => String.t(),
          optional(:boundary_ref) => String.t(),
          optional(:boundary_session_id) => String.t(),
          optional(:session_id) => String.t(),
          optional(:tenant_id) => String.t(),
          optional(:target_id) => String.t()
        }
  @type runtime_observation_result :: {:ok, RuntimeObservation.t()} | {:error, atom()}
  @type boundary_session_result :: {:ok, V1.t()} | {:error, atom()}

  @callback fetch_runtime_observation(runtime_observation_query()) ::
              runtime_observation_result()

  @callback fetch_boundary_session(boundary_session_query()) :: boundary_session_result()
end

defmodule Citadel.Ports.SignalSource do
  @moduledoc """
  Normalizes runtime signals into `Citadel.RuntimeObservation`.
  """

  alias Citadel.RuntimeObservation

  @type raw_signal :: %{optional(atom() | String.t()) => term()}

  @callback normalize_signal(raw_signal()) :: {:ok, RuntimeObservation.t()} | {:error, atom()}
end

defmodule Citadel.Ports.BoundaryLifecycle do
  @moduledoc """
  Projects boundary intent and normalizes boundary lifecycle facts.
  """

  alias Citadel.AttachGrant.V1
  alias Citadel.AuthorityContract.AuthorityDecision.V1, as: AuthorityDecisionV1
  alias Citadel.BoundaryIntent
  alias Citadel.BoundaryLeaseView
  alias Citadel.BoundarySessionDescriptor.V1, as: BoundarySessionDescriptorV1
  alias Citadel.ContractCore.CanonicalJson
  alias Citadel.ExecutionGovernance.V1, as: ExecutionGovernanceV1

  @type boundary_intent_metadata :: %{
          required(:session_id) => String.t(),
          required(:tenant_id) => String.t(),
          required(:target_id) => String.t(),
          optional(:authority_packet) => AuthorityDecisionV1.t(),
          optional(:execution_governance) => ExecutionGovernanceV1.t(),
          optional(:downstream_scope) => String.t(),
          optional(:extensions) => %{optional(String.t()) => CanonicalJson.value()}
        }
  @type boundary_session_source ::
          BoundarySessionDescriptorV1.t()
          | %{
              required(:contract_version) => String.t(),
              required(:boundary_session_id) => String.t(),
              required(:boundary_ref) => String.t(),
              required(:session_id) => String.t(),
              required(:tenant_id) => String.t(),
              required(:target_id) => String.t(),
              required(:boundary_class) => String.t(),
              required(:status) => String.t(),
              required(:attach_mode) => String.t(),
              optional(:lease_expires_at) => DateTime.t() | String.t() | nil,
              optional(:last_heartbeat_at) => DateTime.t() | String.t() | nil,
              optional(:extensions) => %{optional(String.t()) => CanonicalJson.value()}
            }
  @type attach_grant_source ::
          V1.t()
          | %{
              required(:contract_version) => String.t(),
              required(:attach_grant_id) => String.t(),
              required(:boundary_session_id) => String.t(),
              required(:boundary_ref) => String.t(),
              required(:session_id) => String.t(),
              required(:granted_at) => DateTime.t() | String.t(),
              optional(:expires_at) => DateTime.t() | String.t() | nil,
              optional(:credential_handle_refs) => [term()],
              optional(:extensions) => %{optional(String.t()) => CanonicalJson.value()}
            }
  @type boundary_lease_source ::
          BoundaryLeaseView.t()
          | %{
              required(:boundary_ref) => String.t(),
              optional(:last_heartbeat_at) => DateTime.t() | String.t() | nil,
              optional(:expires_at) => DateTime.t() | String.t() | nil,
              required(:staleness_status) => BoundaryLeaseView.staleness_status(),
              required(:lease_epoch) => non_neg_integer(),
              optional(:extensions) => %{optional(String.t()) => CanonicalJson.value()}
            }
  @type lifecycle_submission_result :: {:ok, String.t()} | {:error, atom()}

  @callback submit_boundary_intent(BoundaryIntent.t(), boundary_intent_metadata()) ::
              lifecycle_submission_result()

  @callback normalize_boundary_session(boundary_session_source()) ::
              {:ok, BoundarySessionDescriptorV1.t()} | {:error, atom()}

  @callback normalize_attach_grant(attach_grant_source()) :: {:ok, V1.t()} | {:error, atom()}

  @callback normalize_boundary_lease(boundary_lease_source()) ::
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

  @type lookup_option :: {:scope_id, String.t()}
  @type rank_option ::
          {:scope_id, String.t()}
          | {:session_id, String.t()}
          | {:kind, String.t()}
          | {:limit, pos_integer()}
  @type lookup_options :: [lookup_option()]
  @type rank_options :: [rank_option()]

  @callback put_memory_record(MemoryRecord.t()) ::
              {:ok, %{write_guarantee: :stable_put_by_id | :best_effort}} | {:error, atom()}

  @callback get_memory_record(String.t(), lookup_options()) ::
              {:ok, MemoryRecord.t() | nil} | {:error, atom()}

  @callback rank_memory_records(rank_options()) :: {:ok, [MemoryRecord.t()]} | {:error, atom()}
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
