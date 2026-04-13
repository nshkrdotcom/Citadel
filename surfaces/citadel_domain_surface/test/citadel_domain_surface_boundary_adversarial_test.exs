defmodule Citadel.DomainSurface.BoundaryAdversarialTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import StreamData

  alias Citadel.DomainSurface.Adapters.CitadelAdapter
  alias Citadel.DomainSurface.Error
  alias Citadel.DomainSurface.Examples.{ArticlePublishing, ProvingGround}

  @max_runs 25
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

  defmodule MetadataStruct do
    defstruct [:source, :attempt, :replayed]
  end

  defmodule ContextStruct do
    defstruct [:trace_id, :request_id, :actor_id]
  end

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

  defmodule MintingIdPort do
    def new_id(:trace), do: {:ok, "trace/adversarial-minted"}
  end

  property "command metadata and context normalize across supported boundary forms" do
    check all(
            idempotency_key <- non_blank_string(),
            metadata_entries <- metadata_entries(),
            context_entries <- context_entries(),
            metadata_form <- member_of([:map, :keyword, :struct]),
            context_form <- member_of([:map, :keyword, :struct]),
            max_runs: @max_runs
          ) do
      metadata = build_metadata(metadata_entries, metadata_form)
      context = build_context(context_entries, context_form)

      assert_boundary_safe(
        fn ->
          ProvingGround.compile_workspace(
            %{workspace_id: "workspace/main"},
            idempotency_key: idempotency_key,
            metadata: metadata,
            context: context
          )
        end,
        fn
          {:ok, command} ->
            command.metadata == Map.new(metadata_entries) and
              command.trace_id == context_entries.trace_id and
              command.context == expected_context(context_entries, context_form)

          _ ->
            false
        end
      )
    end
  end

  property "query metadata and context normalize across supported boundary forms" do
    check all(
            metadata_entries <- metadata_entries(),
            context_entries <- context_entries(),
            metadata_form <- member_of([:map, :keyword, :struct]),
            context_form <- member_of([:map, :keyword, :struct]),
            max_runs: @max_runs
          ) do
      metadata = build_metadata(metadata_entries, metadata_form)
      context = build_context(context_entries, context_form)

      assert_boundary_safe(
        fn ->
          ProvingGround.workspace_status(
            %{workspace_id: "workspace/main"},
            metadata: metadata,
            context: context
          )
        end,
        fn
          {:ok, query} ->
            query.metadata == Map.new(metadata_entries) and
              query.trace_id == context_entries.trace_id and
              query.context == expected_context(context_entries, context_form)

          _ ->
            false
        end
      )
    end
  end

  property "malformed metadata returns explicit Domain validation errors for every boundary request kind" do
    check all(
            idempotency_key <- non_blank_string(),
            bad_metadata <- malformed_boundary_value(),
            max_runs: @max_runs
          ) do
      assert_boundary_safe(
        fn ->
          ProvingGround.compile_workspace(
            %{workspace_id: "workspace/main"},
            idempotency_key: idempotency_key,
            metadata: bad_metadata
          )
        end,
        &invalid_error?(&1, :invalid_metadata)
      )

      assert_boundary_safe(
        fn ->
          ProvingGround.workspace_status(
            %{workspace_id: "workspace/main"},
            metadata: bad_metadata
          )
        end,
        &invalid_error?(&1, :invalid_metadata)
      )

      assert_boundary_safe(
        fn ->
          ProvingGround.inspect_dead_letter(
            %{entry_id: "entry-1"},
            idempotency_key: idempotency_key,
            metadata: bad_metadata
          )
        end,
        &invalid_error?(&1, :invalid_metadata)
      )
    end
  end

  property "malformed context returns explicit Domain validation errors rather than crashes" do
    check all(
            idempotency_key <- non_blank_string(),
            bad_context <- malformed_boundary_value(),
            max_runs: @max_runs
          ) do
      assert_boundary_safe(
        fn ->
          ProvingGround.compile_workspace(
            %{workspace_id: "workspace/main"},
            idempotency_key: idempotency_key,
            context: bad_context
          )
        end,
        &invalid_error?(&1, :invalid_context)
      )

      assert_boundary_safe(
        fn ->
          ProvingGround.workspace_status(
            %{workspace_id: "workspace/main"},
            context: bad_context
          )
        end,
        &invalid_error?(&1, :invalid_context)
      )
    end
  end

  property "invalid trace_id values return explicit Domain errors for commands and queries" do
    check all(
            idempotency_key <- non_blank_string(),
            trace_id <- invalid_trace_id(),
            max_runs: @max_runs
          ) do
      assert_boundary_safe(
        fn ->
          ProvingGround.compile_workspace(
            %{workspace_id: "workspace/main"},
            idempotency_key: idempotency_key,
            trace_id: trace_id
          )
        end,
        &invalid_error?(&1, :invalid_trace_id)
      )

      assert_boundary_safe(
        fn ->
          ProvingGround.workspace_status(
            %{workspace_id: "workspace/main"},
            trace_id: trace_id
          )
        end,
        &invalid_error?(&1, :invalid_trace_id)
      )
    end
  end

  property "malformed option bags are rejected explicitly at the public boundary" do
    check all(bad_opts <- malformed_options(), max_runs: @max_runs) do
      assert_boundary_safe(
        fn -> ProvingGround.compile_workspace(%{workspace_id: "workspace/main"}, bad_opts) end,
        &invalid_options_error?/1
      )

      assert_boundary_safe(
        fn ->
          Citadel.DomainSurface.submit(
            ProvingGround.Commands.CompileWorkspace,
            %{workspace_id: "workspace/main"},
            bad_opts
          )
        end,
        &invalid_options_error?/1
      )

      assert_boundary_safe(
        fn ->
          Citadel.DomainSurface.ask(
            ProvingGround.Queries.WorkspaceStatus,
            %{workspace_id: "workspace/main"},
            bad_opts
          )
        end,
        &invalid_options_error?/1
      )
    end
  end

  property "routing malformed request values returns explicit Domain errors instead of function-clause crashes" do
    check all(bad_request <- malformed_route_request(), max_runs: @max_runs) do
      assert_boundary_safe(
        fn -> Citadel.DomainSurface.route(bad_request) end,
        &invalid_route_request?/1
      )
    end
  end

  property "malformed command and query payloads stay inside explicit Domain validation paths" do
    check all(
            idempotency_key <- non_blank_string(),
            bad_payload <- malformed_payload(),
            max_runs: @max_runs
          ) do
      assert_boundary_safe(
        fn ->
          Citadel.DomainSurface.submit(
            ProvingGround.Commands.CompileWorkspace,
            bad_payload,
            idempotency_key: idempotency_key,
            kernel_runtime: FakeKernelRuntime
          )
        end,
        &invalid_error?(&1, :invalid_request)
      )

      assert_boundary_safe(
        fn ->
          Citadel.DomainSurface.ask(
            ProvingGround.Queries.WorkspaceStatus,
            bad_payload,
            kernel_runtime: FakeKernelRuntime
          )
        end,
        &invalid_error?(&1, :invalid_request)
      )
    end
  end

  property "duplicate command retry storms preserve the packet-defined idempotency posture" do
    check all(
            article_id <- non_blank_string(),
            idempotency_key <- non_blank_string(),
            trace_id <- prefixed_string("trace"),
            host_request_ids <-
              uniq_list_of(prefixed_string("host"), min_length: 2, max_length: 6),
            max_runs: @max_runs
          ) do
      {:ok, agent} = start_runtime_agent()

      accepted =
        Enum.map(host_request_ids, fn host_request_id ->
          assert {:ok, result} =
                   ArticlePublishing.publish_article(
                     %{article_id: article_id},
                     idempotency_key: idempotency_key,
                     context: %{
                       trace_id: trace_id,
                       request_id: host_request_id,
                       session_id: "session-retry",
                       tenant_id: "tenant-retry",
                       actor_id: "actor-retry"
                     },
                     kernel_runtime: {CitadelAdapter, runtime_opts(agent)}
                   )

          result
        end)

      [first | rest] = accepted
      submissions = observed_submissions(agent)

      assert first.request_id == idempotency_key
      assert first.trace_id == trace_id
      assert first.metadata.deduplicated? == false
      assert length(submissions) == length(host_request_ids)
      assert Enum.all?(accepted, &(&1.request_id == idempotency_key))
      assert Enum.all?(accepted, &(&1.continuity_revision == first.continuity_revision))
      assert Enum.all?(rest, &(&1.metadata.deduplicated? == true))

      assert Enum.map(submissions, & &1.request_context.request_id) ==
               List.duplicate(idempotency_key, length(host_request_ids))

      assert Enum.map(submissions, & &1.request_context.host_request_id) == host_request_ids
    end
  end

  property "unsupported hidden durable orchestration is rejected explicitly" do
    check all(
            workspace_id <- non_blank_string(),
            idempotency_key <- non_blank_string(),
            max_runs: @max_runs
          ) do
      assert_boundary_safe(
        fn ->
          ProvingGround.rebuild_read_model(
            %{workspace_id: workspace_id},
            idempotency_key: idempotency_key
          )
        end,
        fn
          {:error,
           %Error{
             category: :unsupported,
             code: :unsupported_stateful_orchestration
           }} ->
            true

          _ ->
            false
        end
      )
    end
  end

  property "Citadel rejections preserve bounded classification, retryability, and publication posture" do
    check all(
            fixture <- member_of(@rejection_fixtures),
            article_id <- non_blank_string(),
            idempotency_key <- non_blank_string(),
            trace_id <- prefixed_string("trace"),
            max_runs: @max_runs
          ) do
      {:ok, agent} =
        start_runtime_agent(%{
          submission_reply: {:rejected, fixture_to_rejection(fixture)}
        })

      assert_boundary_safe(
        fn ->
          ArticlePublishing.publish_article(
            %{article_id: article_id},
            idempotency_key: idempotency_key,
            context: %{
              trace_id: trace_id,
              session_id: "session-rejected",
              tenant_id: "tenant-rejected",
              actor_id: "actor-rejected"
            },
            kernel_runtime: {CitadelAdapter, runtime_opts(agent)}
          )
        end,
        fn
          {:error, %Error{} = error} ->
            error.category == :rejected and
              error.code == fixture_atom!(fixture["expected_code"]) and
              error.trace_id == trace_id and
              error.retryability == fixture_atom!(fixture["retryability"]) and
              error.publication == fixture_atom!(fixture["publication_requirement"]) and
              error.source.stage == fixture_atom!(fixture["stage"])

          _ ->
            false
        end
      )
    end
  end

  defp assert_boundary_safe(fun, success?) do
    case safe_call(fun) do
      {:ok, value} ->
        assert success?.(value), "unexpected boundary result: #{inspect(value)}"

      {:error, error} ->
        flunk(
          "unexpected generic crash: #{inspect(error.__struct__)} #{Exception.message(error)}"
        )
    end
  end

  defp safe_call(fun) do
    {:ok, fun.()}
  rescue
    error -> {:error, error}
  end

  defp invalid_error?({:error, %Error{category: :validation, code: code}}, code), do: true
  defp invalid_error?(_result, _code), do: false

  defp invalid_options_error?({:error, %Error{} = error}) do
    error.category == :validation and error.code == :invalid_request and
      error.details[:field] == :options
  end

  defp invalid_options_error?(_result), do: false

  defp invalid_route_request?({:error, %Error{} = error}) do
    error.category == :validation and error.code == :invalid_request and
      error.details[:field] == :request
  end

  defp invalid_route_request?(_result), do: false

  defp metadata_entries do
    fixed_map(%{
      source: non_blank_string(),
      attempt: integer(1..5),
      replayed: boolean()
    })
  end

  defp context_entries do
    fixed_map(%{
      trace_id: prefixed_string("trace"),
      request_id: prefixed_string("host"),
      actor_id: prefixed_string("actor")
    })
  end

  defp build_metadata(entries, :map), do: Map.new(entries)
  defp build_metadata(entries, :keyword), do: Enum.into(entries, [])
  defp build_metadata(entries, :struct), do: struct!(MetadataStruct, Map.new(entries))

  defp build_context(entries, :map), do: Map.new(entries)
  defp build_context(entries, :keyword), do: Enum.into(entries, [])
  defp build_context(entries, :struct), do: struct!(ContextStruct, Map.new(entries))

  defp expected_context(entries, :map), do: Map.new(entries)
  defp expected_context(entries, :keyword), do: Map.new(entries)
  defp expected_context(entries, :struct), do: struct!(ContextStruct, Map.new(entries))

  defp malformed_boundary_value do
    one_of([
      integer(),
      float(),
      boolean(),
      atom(:alphanumeric),
      binary(),
      tuple({integer(), integer()}),
      list_of(integer(), min_length: 1)
    ])
  end

  defp invalid_trace_id do
    one_of([
      constant(""),
      constant("   "),
      integer(),
      constant(true),
      tuple({integer(), integer()})
    ])
  end

  defp malformed_options do
    one_of([
      constant(nil),
      integer(),
      binary(),
      tuple({integer(), integer()}),
      map_of(atom(:alphanumeric), integer(), max_length: 3),
      list_of(integer(), min_length: 1)
    ])
  end

  defp malformed_route_request do
    one_of([
      constant(nil),
      integer(),
      binary(),
      tuple({integer(), integer()}),
      list_of(integer(), min_length: 1),
      map_of(atom(:alphanumeric), integer(), max_length: 3)
    ])
  end

  defp malformed_payload do
    one_of([
      constant(nil),
      integer(),
      float(),
      binary(),
      tuple({integer(), integer()}),
      list_of(integer(), min_length: 1)
    ])
  end

  defp non_blank_string do
    string(:alphanumeric, min_length: 1)
  end

  defp prefixed_string(prefix) do
    map(non_blank_string(), &"#{prefix}/#{&1}")
  end

  defp start_runtime_agent(overrides \\ %{}) do
    Agent.start_link(fn -> Map.merge(base_runtime_state(), overrides) end)
  end

  defp observed_submissions(agent) do
    agent
    |> Agent.get(& &1.submissions)
    |> Enum.reverse()
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
      submissions: [],
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
