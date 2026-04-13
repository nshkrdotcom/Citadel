defmodule Citadel.DomainSurface.BoundaryMutationTest do
  use ExUnit.Case, async: true

  alias Citadel.DomainSurface.Adapters.CitadelAdapter
  alias Citadel.DomainSurface.Error
  alias Citadel.DomainSurface.Examples.{ArticlePublishing, ProvingGround}

  @rejection_fixtures_path Path.expand("fixtures/citadel_rejections.json", __DIR__)
  @rejection_fixtures @rejection_fixtures_path |> File.read!() |> Jason.decode!()
  @fixture_atoms %{
    "ingress_normalization" => :ingress_normalization,
    "scope_resolution" => :scope_resolution,
    "service_admission" => :service_admission,
    "planning" => :planning,
    "authority_compilation" => :authority_compilation,
    "projection" => :projection,
    "request_rejected" => :request_rejected,
    "scope_rejected" => :scope_rejected,
    "service_rejected" => :service_rejected,
    "planning_rejected" => :planning_rejected,
    "policy_rejected" => :policy_rejected,
    "projection_rejected" => :projection_rejected,
    "terminal" => :terminal,
    "after_input_change" => :after_input_change,
    "after_runtime_change" => :after_runtime_change,
    "after_governance_change" => :after_governance_change,
    "host_only" => :host_only,
    "review_projection" => :review_projection,
    "derived_state_attachment" => :derived_state_attachment
  }

  defmodule FakeKernelRuntime do
    @behaviour Citadel.DomainSurface.Ports.KernelRuntime

    @impl true
    def dispatch_command(request) do
      {:ok,
       %{
         handled: request.name,
         request_type: request.__struct__,
         idempotency_key: Map.get(request, :idempotency_key),
         trace_id: Map.get(request, :trace_id)
       }}
    end

    @impl true
    def run_query(query) do
      {:ok,
       %{
         handled: query.name,
         request_type: query.__struct__,
         trace_id: query.trace_id
       }}
    end
  end

  defmodule FakeExternalIntegration do
    @behaviour Citadel.DomainSurface.Ports.ExternalIntegration

    @impl true
    def dispatch_command(request) do
      {:ok,
       %{
         handled: request.name,
         request_type: request.__struct__,
         lower_seam: :external_integration,
         idempotency_key: Map.get(request, :idempotency_key),
         trace_id: Map.get(request, :trace_id)
       }}
    end

    @impl true
    def run_query(query) do
      {:ok,
       %{
         handled: query.name,
         request_type: query.__struct__,
         lower_seam: :external_integration,
         trace_id: query.trace_id
       }}
    end
  end

  defmodule BadCommandDefinition do
    def definition, do: :bad_definition
  end

  defmodule RequestSubmissionStub do
    @behaviour Citadel.DomainSurface.Adapters.CitadelAdapter.RequestSubmission

    @impl true
    def submit_envelope(_envelope, request_context, opts) do
      agent = Keyword.fetch!(opts, :agent)

      Agent.get_and_update(agent, fn state ->
        case state.submission_reply do
          {:rejected, rejection} ->
            {{:rejected, rejection}, state}

          :accepted ->
            accepted = %{
              ingress_path: :direct_intent_envelope,
              lifecycle_event: :attached,
              continuity_revision: 1,
              deduplicated?:
                Map.has_key?(state.accepted_by_idempotency, request_context.idempotency_key)
            }

            state =
              put_in(state.accepted_by_idempotency[request_context.idempotency_key], accepted)

            {{:accepted, accepted}, state}
        end
      end)
    end
  end

  defmodule MintingIdPort do
    def new_id(:trace), do: {:ok, "trace/mutation-minted"}
  end

  test "router keeps command, query, admin, and optional integration paths explicit" do
    assert {:ok, command_result} =
             Citadel.DomainSurface.submit(
               ProvingGround.Commands.CompileWorkspace,
               %{workspace_id: "workspace/main"},
               idempotency_key: "cmd-router-1",
               context: %{trace_id: "trace/router-1"},
               kernel_runtime: FakeKernelRuntime
             )

    assert command_result.handled == :compile_workspace
    assert command_result.idempotency_key == "cmd-router-1"

    assert {:ok, query_result} =
             Citadel.DomainSurface.ask(
               ProvingGround.Queries.WorkspaceStatus,
               %{workspace_id: "workspace/main"},
               context: %{trace_id: "trace/router-2"},
               kernel_runtime: FakeKernelRuntime
             )

    assert query_result.handled == :workspace_status
    assert query_result.trace_id == "trace/router-2"

    assert {:ok, admin_result} =
             Citadel.DomainSurface.maintain(
               ProvingGround.AdminCommands.RecoverDeadLetters,
               %{selector: [dead_letter_reason: "projection_backend_down"]},
               idempotency_key: "admin-router-1",
               context: %{trace_id: "trace/router-3"},
               kernel_runtime: FakeKernelRuntime
             )

    assert admin_result.handled == :recover_dead_letters
    assert admin_result.idempotency_key == "admin-router-1"

    assert {:error, %Error{} = not_configured} =
             Citadel.DomainSurface.submit(
               ProvingGround.Commands.RecordOperatorEvidence,
               %{evidence_id: "evidence-1"},
               idempotency_key: "cmd-router-2"
             )

    assert not_configured.category == :configuration
    assert not_configured.code == :not_configured
    assert not_configured.details[:component] == :external_integration

    assert {:ok, integration_result} =
             Citadel.DomainSurface.submit(
               ProvingGround.Commands.RecordOperatorEvidence,
               %{evidence_id: "evidence-2"},
               idempotency_key: "cmd-router-3",
               context: %{trace_id: "trace/router-4"},
               external_integration: FakeExternalIntegration
             )

    assert integration_result.handled == :record_operator_evidence
    assert integration_result.lower_seam == :external_integration
    assert integration_result.idempotency_key == "cmd-router-3"
  end

  test "validation remains explicit for malformed options, metadata, trace ids, and definitions" do
    assert {:error, %Error{} = invalid_opts} =
             ProvingGround.compile_workspace(
               %{workspace_id: "workspace/main"},
               %{idempotency_key: "cmd-invalid-opts"}
             )

    assert invalid_opts.category == :validation
    assert invalid_opts.code == :invalid_request
    assert invalid_opts.details[:field] == :options

    assert {:error, %Error{} = invalid_metadata} =
             ProvingGround.compile_workspace(
               %{workspace_id: "workspace/main"},
               idempotency_key: "cmd-invalid-metadata",
               metadata: [1, 2]
             )

    assert invalid_metadata.code == :invalid_metadata

    assert {:error, %Error{} = invalid_trace_id} =
             ProvingGround.workspace_status(
               %{workspace_id: "workspace/main"},
               trace_id: ""
             )

    assert invalid_trace_id.code == :invalid_trace_id

    assert {:error, %Error{} = missing_idempotency} =
             ProvingGround.compile_workspace(%{workspace_id: "workspace/main"})

    assert missing_idempotency.code == :missing_idempotency_key

    assert {:error, %Error{} = invalid_definition} =
             Citadel.DomainSurface.command(BadCommandDefinition, %{},
               idempotency_key: "cmd-invalid-definition"
             )

    assert invalid_definition.code == :invalid_definition
  end

  test "unsupported hidden orchestration and malformed route requests fail closed with Domain errors" do
    assert {:error, %Error{} = unsupported} =
             ProvingGround.rebuild_read_model(
               %{workspace_id: "workspace/main"},
               idempotency_key: "cmd-unsupported-1"
             )

    assert unsupported.category == :unsupported
    assert unsupported.code == :unsupported_stateful_orchestration

    assert {:error, %Error{} = invalid_request} = Citadel.DomainSurface.route(:not_a_request)

    assert invalid_request.category == :validation
    assert invalid_request.code == :invalid_request
    assert invalid_request.details[:field] == :request
  end

  test "duplicate retries keep the same idempotent request identity" do
    {:ok, agent} = start_runtime_agent()

    assert {:ok, first} =
             ArticlePublishing.publish_article(
               %{article_id: "article-retry"},
               idempotency_key: "pub-retry",
               context: %{
                 trace_id: "trace/retry",
                 request_id: "host-retry-a",
                 session_id: "session-retry",
                 tenant_id: "tenant-retry",
                 actor_id: "actor-retry"
               },
               kernel_runtime: {CitadelAdapter, runtime_opts(agent)}
             )

    assert {:ok, second} =
             ArticlePublishing.publish_article(
               %{article_id: "article-retry"},
               idempotency_key: "pub-retry",
               context: %{
                 trace_id: "trace/retry",
                 request_id: "host-retry-b",
                 session_id: "session-retry",
                 tenant_id: "tenant-retry",
                 actor_id: "actor-retry"
               },
               kernel_runtime: {CitadelAdapter, runtime_opts(agent)}
             )

    assert first.request_id == "pub-retry"
    assert second.request_id == "pub-retry"
    assert first.metadata.deduplicated? == false
    assert second.metadata.deduplicated? == true
  end

  test "rejection translation preserves bounded stage, retryability, and publication data" do
    fixture = Enum.find(@rejection_fixtures, &(&1["stage"] == "planning"))

    {:ok, agent} =
      start_runtime_agent(%{
        submission_reply: {:rejected, fixture_to_rejection(fixture)}
      })

    assert {:error, %Error{} = error} =
             ArticlePublishing.publish_article(
               %{article_id: "article-rejected"},
               idempotency_key: "pub-rejected",
               context: %{
                 trace_id: "trace/rejected",
                 session_id: "session-rejected",
                 tenant_id: "tenant-rejected",
                 actor_id: "actor-rejected"
               },
               kernel_runtime: {CitadelAdapter, runtime_opts(agent)}
             )

    assert error.category == :rejected
    assert error.code == :planning_rejected
    assert error.trace_id == "trace/rejected"
    assert error.retryability == :after_input_change
    assert error.publication == :host_only
    assert error.source.stage == :planning
  end

  defp start_runtime_agent(overrides \\ %{}) do
    Agent.start_link(fn -> Map.merge(base_runtime_state(), overrides) end)
  end

  defp runtime_opts(agent) do
    [
      id_port: MintingIdPort,
      request_submission: RequestSubmissionStub,
      request_submission_opts: [agent: agent],
      context_defaults: %{
        tenant_id: "tenant-default",
        actor_id: "actor-default",
        session_id: "session-default",
        environment: "test"
      }
    ]
  end

  defp base_runtime_state do
    %{
      submission_reply: :accepted,
      accepted_by_idempotency: %{}
    }
  end

  defp fixture_to_rejection(fixture) do
    %{
      rejection_id: fixture["rejection_id"],
      stage: fixture_atom!(fixture["stage"]),
      reason_code: fixture["reason_code"],
      summary: fixture["summary"],
      retryability: fixture_atom!(fixture["retryability"]),
      publication_requirement: fixture_atom!(fixture["publication_requirement"]),
      extensions: %{"fixture" => true}
    }
  end

  defp fixture_atom!(value), do: Map.fetch!(@fixture_atoms, value)
end
