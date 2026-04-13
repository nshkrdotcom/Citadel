defmodule Citadel.DomainSurface.ConformanceTest do
  use ExUnit.Case, async: true

  alias Citadel.DomainSurface.Adapters.CitadelAdapter
  alias Citadel.DomainSurface.Error
  alias Citadel.DomainSurface.Examples.ArticlePublishing

  defmodule RequestSubmissionStub do
    @behaviour Citadel.DomainSurface.Adapters.CitadelAdapter.RequestSubmission

    @impl true
    def submit_envelope(envelope, request_context, opts) do
      agent = Keyword.fetch!(opts, :agent)

      Agent.get_and_update(agent, fn state ->
        submission = %{envelope: envelope, request_context: request_context}
        state = update_in(state.submissions, &[submission | &1])

        case state.submission_reply do
          {:rejected, rejection} ->
            {{:rejected, rejection}, state}

          :accepted ->
            {accepted, state} = accept_submission(state, request_context)
            {{:accepted, accepted}, state}
        end
      end)
    end

    defp accept_submission(state, request_context) do
      case Map.fetch(state.accepted_by_idempotency, request_context.idempotency_key) do
        {:ok, accepted} ->
          {Map.put(accepted, :deduplicated?, true), state}

        :error ->
          accepted = %{
            ingress_path: :direct_intent_envelope,
            lifecycle_event: :attached,
            continuity_revision: map_size(state.accepted_by_idempotency) + 1,
            deduplicated?: false
          }

          {accepted,
           put_in(state.accepted_by_idempotency[request_context.idempotency_key], accepted)}
      end
    end
  end

  defmodule QuerySurfaceStub do
    @behaviour Citadel.DomainSurface.Adapters.CitadelAdapter.QuerySurface

    @impl true
    def fetch_boundary_session(query, opts) do
      agent = Keyword.fetch!(opts, :agent)

      Agent.get_and_update(agent, fn state ->
        state = update_in(state.boundary_queries, &[query | &1])
        response = Map.put(state.boundary_session_response, :target_id, query.target_id)
        {{:ok, response}, state}
      end)
    end

    @impl true
    def fetch_runtime_observation(_query, _opts), do: {:error, :unsupported}
  end

  defmodule MintingIdPort do
    def new_id(:trace), do: {:ok, "trace/conformance-minted"}
  end

  test "keeps the host-facing example surface semantic and free of raw signals or process names" do
    assert {:ok, command} =
             ArticlePublishing.publish_article_command(
               %{article_id: "article-plain-1"},
               idempotency_key: "pub-plain-1"
             )

    assert {:ok, query} =
             ArticlePublishing.publication_status_query(%{article_id: "article-plain-1"})

    assert command.name == :publish_article
    assert query.name == :publication_status
    assert command.input == %{article_id: "article-plain-1"}
    assert query.params == %{article_id: "article-plain-1"}
    assert command.route.operation == :publish_article
    assert query.route.operation == :publication_status

    refute Enum.any?(Map.keys(command.metadata), &(&1 in [:signal, :signal_name, :process_name]))
    refute Enum.any?(Map.keys(query.metadata), &(&1 in [:signal, :signal_name, :process_name]))
  end

  test "proves success through the host-facing command helper while preserving host trace lineage" do
    {:ok, agent} = start_runtime_agent()

    assert {:ok, accepted} =
             ArticlePublishing.publish_article(
               %{article_id: "article-42"},
               idempotency_key: "pub-42",
               context: %{
                 trace_id: "trace/host-42",
                 request_id: "host-req-42",
                 session_id: "session-42",
                 tenant_id: "tenant-42",
                 actor_id: "actor-42"
               },
               kernel_runtime: {CitadelAdapter, runtime_opts(agent)}
             )

    assert accepted.request_id == "pub-42"
    assert accepted.trace_id == "trace/host-42"
    assert accepted.session_id == "session-42"
    assert accepted.metadata.deduplicated? == false

    [submission] = observed_submissions(agent)
    assert submission.request_context.request_id == "pub-42"
    assert submission.request_context.host_request_id == "host-req-42"
    assert submission.request_context.trace_id == "trace/host-42"
    assert submission.request_context.trace_origin == :host
    assert submission.envelope.extensions["citadel_domain_surface"]["idempotency_key"] == "pub-42"
    assert submission.envelope.extensions["citadel_domain_surface"]["trace_origin"] == "host"
  end

  test "proves duplicate command retry behavior with the same idempotency_key" do
    {:ok, agent} = start_runtime_agent()

    assert {:ok, first} =
             ArticlePublishing.publish_article(
               %{article_id: "article-retry-1"},
               idempotency_key: "pub-retry-1",
               context: %{
                 trace_id: "trace/retry-1",
                 request_id: "host-retry-a"
               },
               kernel_runtime: {CitadelAdapter, runtime_opts(agent)}
             )

    assert {:ok, second} =
             ArticlePublishing.publish_article(
               %{article_id: "article-retry-1"},
               idempotency_key: "pub-retry-1",
               context: %{
                 trace_id: "trace/retry-1",
                 request_id: "host-retry-b"
               },
               kernel_runtime: {CitadelAdapter, runtime_opts(agent)}
             )

    assert first.request_id == "pub-retry-1"
    assert second.request_id == "pub-retry-1"
    assert first.continuity_revision == second.continuity_revision
    assert first.metadata.deduplicated? == false
    assert second.metadata.deduplicated? == true

    submissions = observed_submissions(agent)

    assert length(submissions) == 2
    assert Enum.all?(submissions, &(&1.request_context.request_id == "pub-retry-1"))

    assert Enum.map(submissions, & &1.request_context.host_request_id) == [
             "host-retry-a",
             "host-retry-b"
           ]
  end

  test "proves explicit rejection returns a Domain error without leaking raw Citadel runtime details" do
    {:ok, agent} =
      start_runtime_agent(%{
        submission_reply:
          {:rejected,
           %{
             rejection_id: "rejection/conformance-1",
             stage: :planning,
             reason_code: "publication_requires_review",
             summary: "publication requires editorial review",
             retryability: :after_input_change,
             publication_requirement: :host_only,
             extensions: %{"rejected" => true}
           }}
      })

    assert {:error, %Error{} = error} =
             ArticlePublishing.publish_article(
               %{article_id: "article-rejected-1"},
               idempotency_key: "pub-rejected-1",
               context: %{
                 trace_id: "trace/rejected-1",
                 session_id: "session-rejected-1",
                 tenant_id: "tenant-rejected-1",
                 actor_id: "actor-rejected-1"
               },
               kernel_runtime: {CitadelAdapter, runtime_opts(agent)}
             )

    assert error.category == :rejected
    assert error.code == :planning_rejected
    assert error.trace_id == "trace/rejected-1"
    assert error.retryability == :after_input_change
    assert error.publication == :host_only
    assert error.details.reason_code == "publication_requires_review"

    assert error.source == %{
             system: :citadel,
             rejection_id: "rejection/conformance-1",
             stage: :planning,
             reason_code: "publication_requires_review"
           }
  end

  test "proves query trace minting at the Domain boundary when the host omits trace_id" do
    {:ok, agent} = start_runtime_agent()

    assert {:ok, descriptor} =
             ArticlePublishing.publication_status(
               %{article_id: "article-query-1"},
               context: %{tenant_id: "tenant-query-1"},
               kernel_runtime: {CitadelAdapter, runtime_opts(agent)}
             )

    assert Map.get(descriptor, :target_id) == "article-query-1"
    assert Map.get(descriptor, :status) == "attached"

    [query] = observed_boundary_queries(agent)
    assert query.downstream_scope == "publication_status"
    assert query.target_id == "article-query-1"
    assert query.tenant_id == "tenant-query-1"
    assert query.trace_id == "trace/conformance-minted"
  end

  defp start_runtime_agent(overrides \\ %{}) do
    Agent.start_link(fn -> Map.merge(base_runtime_state(), overrides) end)
  end

  defp observed_submissions(agent) do
    agent
    |> Agent.get(& &1.submissions)
    |> Enum.reverse()
  end

  defp observed_boundary_queries(agent) do
    agent
    |> Agent.get(& &1.boundary_queries)
    |> Enum.reverse()
  end

  defp runtime_opts(agent, overrides \\ []) do
    [
      id_port: MintingIdPort,
      request_submission: RequestSubmissionStub,
      request_submission_opts: [agent: agent],
      query_surface: QuerySurfaceStub,
      query_surface_opts: [agent: agent],
      context_defaults: %{
        tenant_id: "tenant-default",
        actor_id: "actor-default",
        session_id: "session-default",
        environment: "test"
      }
    ]
    |> Keyword.merge(overrides)
  end

  defp base_runtime_state do
    %{
      submissions: [],
      boundary_queries: [],
      submission_reply: :accepted,
      accepted_by_idempotency: %{},
      boundary_session_response: %{
        contract_version: "v1",
        boundary_session_id: "boundary-session-1",
        boundary_ref: "boundary/article/default",
        session_id: "session-default",
        tenant_id: "tenant-default",
        target_id: "article-default",
        boundary_class: "publication_session",
        status: "attached",
        attach_mode: "fresh_or_reuse",
        extensions: %{}
      }
    }
  end
end
