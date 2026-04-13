defmodule Citadel.DomainSurface.TelemetryAndObservabilityTest do
  use ExUnit.Case, async: false

  alias Citadel.DomainSurface.Adapters.CitadelAdapter
  alias Citadel.DomainSurface.Adapters.CitadelAdapter.RequestContext
  alias Citadel.DomainSurface.Error
  alias Citadel.DomainSurface.Examples.ArticlePublishing
  alias Citadel.DomainSurface.Examples.ProvingGround
  alias Citadel.DomainSurface.Telemetry

  defmodule RequestSubmissionStub do
    @behaviour Citadel.DomainSurface.Adapters.CitadelAdapter.RequestSubmission

    @impl true
    def submit_envelope(_envelope, %RequestContext{} = request_context, opts) do
      agent = Keyword.fetch!(opts, :agent)

      Agent.get_and_update(agent, fn state ->
        case state.submission_result do
          :accepted ->
            {accepted, state} = accept_submission(state, request_context)
            {{:accepted, accepted}, state}

          {:rejected, rejection} ->
            {{:rejected, rejection}, state}

          {:error, reason} ->
            {{:error, reason}, state}
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
            request_id: request_context.request_id,
            session_id: request_context.session_id,
            trace_id: request_context.trace_id,
            deduplicated?: false
          }

          {accepted,
           put_in(state.accepted_by_idempotency[request_context.idempotency_key], accepted)}
      end
    end
  end

  defmodule MaintenanceSurfaceStub do
    @behaviour Citadel.DomainSurface.Adapters.CitadelAdapter.MaintenanceSurface

    @impl true
    def inspect_dead_letter(entry_id, %RequestContext{} = request_context, _opts) do
      {:ok, %{entry_id: entry_id, request_id: request_context.request_id}}
    end

    @impl true
    def clear_dead_letter(entry_id, _override_reason, %RequestContext{} = request_context, _opts) do
      {:ok, %{entry_id: entry_id, request_id: request_context.request_id}}
    end

    @impl true
    def retry_dead_letter(entry_id, _override_reason, %RequestContext{} = request_context, _opts) do
      {:ok, %{entry_id: entry_id, request_id: request_context.request_id}}
    end

    @impl true
    def replace_dead_letter(
          entry_id,
          _replacement_entry,
          _override_reason,
          %RequestContext{} = request_context,
          _opts
        ) do
      {:ok, %{entry_id: entry_id, request_id: request_context.request_id}}
    end

    @impl true
    def recover_dead_letters(selector, operation, %RequestContext{} = request_context, _opts) do
      {:ok,
       %{
         selector: selector,
         recovery_operation: operation,
         affected_count: 2,
         request_id: request_context.request_id
       }}
    end
  end

  @rejection %{
    rejection_id: "rejection/telemetry-1",
    stage: :planning,
    reason_code: "publication_requires_review",
    summary: "publication requires editorial review",
    retryability: :after_input_change,
    publication_requirement: :host_only,
    extensions: %{"fixture" => true}
  }

  setup do
    :ok
  end

  test "emits command submit and idempotency hit or miss telemetry with bounded metadata" do
    {:ok, agent} = start_runtime_agent()

    attach_telemetry([:command_submit, :command_idempotency])

    assert {:ok, _accepted} =
             ArticlePublishing.publish_article(
               %{article_id: "article-telemetry-1"},
               idempotency_key: "pub-telemetry-1",
               context: %{trace_id: "trace/pub-telemetry-1"},
               kernel_runtime: {CitadelAdapter, runtime_opts(agent)}
             )

    assert {:ok, _accepted} =
             ArticlePublishing.publish_article(
               %{article_id: "article-telemetry-1"},
               idempotency_key: "pub-telemetry-1",
               context: %{trace_id: "trace/pub-telemetry-1"},
               kernel_runtime: {CitadelAdapter, runtime_opts(agent)}
             )

    assert_event(:command_submit, %{count: 1}, %{
      request_name: :publish_article,
      dispatch_via: :kernel_runtime
    })

    assert_event(:command_idempotency, %{count: 1}, %{
      request_name: :publish_article,
      dispatch_via: :kernel_runtime,
      classification: :miss
    })

    assert_event(:command_submit, %{count: 1}, %{
      request_name: :publish_article,
      dispatch_via: :kernel_runtime
    })

    assert_event(:command_idempotency, %{count: 1}, %{
      request_name: :publish_article,
      dispatch_via: :kernel_runtime,
      classification: :hit
    })
  end

  test "emits command rejection telemetry with bounded classification metadata" do
    {:ok, agent} = start_runtime_agent(%{submission_result: {:rejected, @rejection}})

    attach_telemetry([:command_rejected])

    assert {:error, %Error{} = error} =
             ArticlePublishing.publish_article(
               %{article_id: "article-rejected-telemetry"},
               idempotency_key: "pub-rejected-telemetry",
               context: %{trace_id: "trace/rejected-telemetry"},
               kernel_runtime: {CitadelAdapter, runtime_opts(agent)}
             )

    assert error.code == :planning_rejected

    assert_event(:command_rejected, %{count: 1}, %{
      request_name: :publish_article,
      dispatch_via: :kernel_runtime,
      rejection_code: :planning_rejected,
      rejection_stage: :planning,
      reason_code: "publication_requires_review",
      retryability: :after_input_change,
      publication: :host_only
    })
  end

  test "emits adapter failure telemetry with bounded degradation classifications" do
    {:ok, agent} = start_runtime_agent(%{submission_result: {:error, :timeout}})

    attach_telemetry([:adapter_failure])

    assert {:error, %Error{} = error} =
             ArticlePublishing.publish_article(
               %{article_id: "article-failure-telemetry"},
               idempotency_key: "pub-failure-telemetry",
               context: %{trace_id: "trace/failure-telemetry"},
               kernel_runtime: {CitadelAdapter, runtime_opts(agent)}
             )

    assert error.details.reason == :timeout

    assert_event(:adapter_failure, %{count: 1}, %{
      request_type: :command,
      request_name: :publish_article,
      dispatch_via: :kernel_runtime,
      component: :request_submission,
      failure_class: :timeout
    })
  end

  test "emits adapter circuit-open telemetry with bounded degradation classifications" do
    {:ok, agent} = start_runtime_agent(%{submission_result: {:error, :circuit_open}})

    attach_telemetry([:adapter_circuit_open])

    assert {:error, %Error{} = error} =
             ArticlePublishing.publish_article(
               %{article_id: "article-circuit-telemetry"},
               idempotency_key: "pub-circuit-telemetry",
               context: %{trace_id: "trace/circuit-telemetry"},
               kernel_runtime: {CitadelAdapter, runtime_opts(agent)}
             )

    assert error.details.reason == :circuit_open

    assert_event(:adapter_circuit_open, %{count: 1}, %{
      request_type: :command,
      request_name: :publish_article,
      dispatch_via: :kernel_runtime,
      component: :request_submission,
      failure_class: :circuit_open
    })
  end

  test "emits admin maintenance telemetry without leaking operator payload" do
    {:ok, agent} = start_runtime_agent()

    attach_telemetry([:admin_maintenance])

    assert {:ok, result} =
             Citadel.DomainSurface.maintain(
               ProvingGround.AdminCommands.RecoverDeadLetters,
               %{selector: [dead_letter_reason: "projection_backend_down"]},
               idempotency_key: "admin-telemetry-1",
               context: %{trace_id: "trace/admin-telemetry-1"},
               kernel_runtime: {CitadelAdapter, runtime_opts(agent)}
             )

    assert result.operation == :recover_dead_letters

    assert_event(:admin_maintenance, %{count: 1}, %{
      admin_name: :recover_dead_letters,
      dispatch_via: :kernel_runtime,
      operation: :recover_dead_letters,
      auditable?: true
    })
  end

  defp start_runtime_agent(overrides \\ %{}) do
    Agent.start_link(fn ->
      Map.merge(
        %{
          submission_result: :accepted,
          accepted_by_idempotency: %{}
        },
        overrides
      )
    end)
  end

  defp runtime_opts(agent) do
    [
      request_submission: RequestSubmissionStub,
      request_submission_opts: [agent: agent],
      maintenance_surface: MaintenanceSurfaceStub,
      maintenance_surface_opts: [agent: agent],
      context_defaults: %{
        tenant_id: "tenant-default",
        actor_id: "actor-default",
        session_id: "session-default",
        environment: "test"
      }
    ]
  end

  defp attach_telemetry(event_keys) do
    handler_id = "jido-domain-telemetry-#{System.unique_integer([:positive, :monotonic])}"
    events = Enum.map(event_keys, &Telemetry.event_name/1)
    parent = self()

    :ok =
      :telemetry.attach_many(
        handler_id,
        events,
        &__MODULE__.handle_telemetry/4,
        parent
      )

    on_exit(fn ->
      :telemetry.detach(handler_id)
    end)
  end

  defp assert_event(event_key, expected_measurements, expected_metadata) do
    event_name = Telemetry.event_name(event_key)

    assert_receive {:telemetry_event, ^event_name, measurements, metadata}
    assert measurements == expected_measurements
    assert metadata == expected_metadata
  end

  def handle_telemetry(event, measurements, metadata, target) do
    send(target, {:telemetry_event, event, measurements, metadata})
  end
end
