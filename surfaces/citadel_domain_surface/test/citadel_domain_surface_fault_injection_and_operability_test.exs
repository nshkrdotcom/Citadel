citadel_root = Path.expand("../../..", __DIR__)

Code.require_file(Path.join(citadel_root, "dev/docker/toxiproxy/test_support.exs"))

defmodule Citadel.DomainSurface.Wave22FaultSupport do
  @moduledoc false

  alias Citadel.BoundarySessionDescriptor.V1, as: BoundarySessionDescriptorV1
  alias Citadel.BridgeCircuit
  alias Citadel.BridgeCircuitPolicy
  alias Citadel.TestSupport.ToxiproxyHarness
  alias Citadel.DomainSurface.Error

  @default_timeout 500

  def initial_probe_state do
    %{
      network_attempts: [],
      worker_task_starts: 0,
      semantic_submit_counts: %{},
      ambiguous_once_keys: MapSet.new()
    }
  end

  def bridge_policy(overrides \\ %{}) do
    BridgeCircuitPolicy.new!(
      %{
        failure_threshold: 3,
        window_ms: 5_000,
        cooldown_ms: 1_000,
        half_open_max_inflight: 1,
        scope_key_mode: "bridge_global",
        extensions: %{}
      }
      |> Map.merge(Map.new(overrides))
    )
  end

  def bridge_state(policy) do
    Agent.start_link(fn ->
      %{
        circuit: BridgeCircuit.new!(policy: policy),
        receipts_by_dedupe_key: %{},
        pending_operations: %{},
        pending_dedupe_keys: %{}
      }
    end)
  end

  def socket_round_trip(kind, request_id, opts, on_success)
      when is_atom(kind) and is_binary(request_id) and is_list(opts) and
             is_function(on_success, 0) do
    bridge_state = Keyword.fetch!(opts, :bridge_state)
    dedupe_key = Keyword.get(opts, :dedupe_key)
    scope_key = Keyword.get(opts, :scope_key, "#{kind}:socket")

    handle_socket_operation(
      begin_operation(bridge_state, scope_key, dedupe_key),
      kind,
      request_id,
      Keyword.put(opts, :on_success, on_success)
    )
  end

  def attempt_count(agent, kind) when is_atom(kind) do
    Agent.get(agent, fn state ->
      Enum.count(state.network_attempts, &(&1.kind == kind))
    end)
  end

  def worker_task_starts(agent) do
    Agent.get(agent, & &1.worker_task_starts)
  end

  def semantic_submit_count(agent, idempotency_key) do
    Agent.get(agent, fn state ->
      Map.get(state.semantic_submit_counts, idempotency_key, 0)
    end)
  end

  def next_semantic_submit_revision(agent, idempotency_key) do
    Agent.get_and_update(agent, fn state ->
      semantic_submit_counts =
        Map.update(state.semantic_submit_counts, idempotency_key, 1, &(&1 + 1))

      {Map.fetch!(semantic_submit_counts, idempotency_key),
       %{state | semantic_submit_counts: semantic_submit_counts}}
    end)
  end

  def accepted_attrs(request_context, continuity_revision) do
    %{
      ingress_path: :direct_intent_envelope,
      lifecycle_event: :attached,
      continuity_revision: continuity_revision,
      request_id: request_context.request_id,
      session_id: request_context.session_id,
      trace_id: request_context.trace_id,
      metadata: %{
        idempotency_key: request_context.idempotency_key,
        trace_origin: request_context.trace_origin
      }
    }
  end

  def boundary_session_descriptor(query) when is_map(query) do
    target_id = Map.get(query, :target_id, Map.get(query, "target_id", "article-default"))

    %{
      contract_version: BoundarySessionDescriptorV1.contract_version(),
      boundary_session_id: "boundary-session/#{target_id}",
      boundary_ref: "boundary/article/#{target_id}",
      session_id: Map.get(query, :session_id, Map.get(query, "session_id", "session-default")),
      tenant_id: Map.get(query, :tenant_id, Map.get(query, "tenant_id", "tenant-default")),
      target_id: target_id,
      boundary_class: "publication_session",
      status: "attached",
      attach_mode: "fresh_or_reuse",
      extensions: %{}
    }
  end

  def maintenance_result(operation, request_context, attrs \\ %{}) do
    %{
      operation: operation,
      entry_id: Map.get(attrs, :entry_id, Map.get(attrs, "entry_id", "entry-default")),
      request_id: request_context.request_id,
      trace_id: request_context.trace_id,
      session: %{
        session_id: request_context.session_id
      }
    }
  end

  def external_result(request) do
    %{
      handled: request.name,
      request_type: request.__struct__,
      lower_seam: :external_integration,
      idempotency_key: Map.get(request, :idempotency_key),
      trace_id: Map.get(request, :trace_id)
    }
  end

  def configuration_error(component, reason, trace_id, route) do
    Error.configuration(
      :not_configured,
      "#{component} degraded under hostile downstream conditions",
      component: component,
      reason: reason,
      trace_id: trace_id,
      route: route
    )
  end

  defp ambiguous_submit?(nil, _opts), do: false

  defp ambiguous_submit?(dedupe_key, opts) do
    case Keyword.get(opts, :ambiguous_once?, false) do
      false ->
        false

      true ->
        opts
        |> Keyword.fetch!(:agent)
        |> record_ambiguous_submit_once(dedupe_key)
    end
  end

  defp record_ambiguous_submit_once(agent, dedupe_key) do
    Agent.get_and_update(agent, fn state ->
      case MapSet.member?(state.ambiguous_once_keys, dedupe_key) do
        true ->
          {false, state}

        false ->
          {true,
           %{state | ambiguous_once_keys: MapSet.put(state.ambiguous_once_keys, dedupe_key)}}
      end
    end)
  end

  defp network_request(kind, request_id, opts) do
    agent = Keyword.fetch!(opts, :agent)
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    url = Keyword.get(opts, :url, ToxiproxyHarness.proxy_url("/"))
    worker_supervisor = Keyword.get(opts, :worker_supervisor)

    Agent.update(agent, fn state ->
      %{
        state
        | network_attempts: [%{kind: kind, request_id: request_id} | state.network_attempts]
      }
    end)

    fun = fn ->
      ToxiproxyHarness.request_url(
        :get,
        url,
        timeout: timeout,
        connect_timeout: timeout
      )
      |> ToxiproxyHarness.normalize_http_result("receipt:#{kind}:#{request_id}")
    end

    case worker_supervisor do
      nil ->
        fun.()

      supervisor ->
        Agent.update(agent, fn state ->
          %{state | worker_task_starts: state.worker_task_starts + 1}
        end)

        task = Task.Supervisor.async_nolink(supervisor, fun)
        Task.await(task, timeout + 250)
    end
  catch
    :exit, _reason -> {:error, :unknown}
  end

  defp begin_operation(server, scope_key, dedupe_key) do
    Agent.get_and_update(server, fn state ->
      cond do
        is_binary(dedupe_key) and Map.has_key?(state.receipts_by_dedupe_key, dedupe_key) ->
          {{:duplicate, Map.fetch!(state.receipts_by_dedupe_key, dedupe_key)}, state}

        is_binary(dedupe_key) and Map.has_key?(state.pending_dedupe_keys, dedupe_key) ->
          {{:error, :submission_inflight}, state}

        true ->
          allow_operation(state, scope_key, dedupe_key)
      end
    end)
  end

  defp handle_socket_operation({:duplicate, receipt}, _kind, _request_id, _opts),
    do: {:duplicate, receipt}

  defp handle_socket_operation({:error, reason}, _kind, _request_id, _opts), do: {:error, reason}

  defp handle_socket_operation({:ok, token}, kind, request_id, opts) do
    bridge_state = Keyword.fetch!(opts, :bridge_state)
    dedupe_key = Keyword.get(opts, :dedupe_key)
    on_success = Keyword.fetch!(opts, :on_success)

    case network_request(kind, request_id, opts) do
      {:ok, _receipt_ref} ->
        success = on_success.()
        {:ok, success} = finish_operation(bridge_state, token, {:ok, success})
        maybe_ambiguous_submit(success, dedupe_key, opts)

      {:error, reason} ->
        {:error, reason} = finish_operation(bridge_state, token, {:error, reason})
        {:error, reason}
    end
  end

  defp maybe_ambiguous_submit(success, dedupe_key, opts) do
    if ambiguous_submit?(dedupe_key, opts), do: {:error, :ambiguous_submit}, else: {:ok, success}
  end

  defp allow_operation(state, scope_key, dedupe_key) do
    case BridgeCircuit.allow(state.circuit, scope_key) do
      {:ok, circuit} ->
        token = make_ref()

        next_state =
          state
          |> Map.put(:circuit, circuit)
          |> put_in([:pending_operations, token], %{scope_key: scope_key, dedupe_key: dedupe_key})
          |> maybe_put_pending_dedupe_key(dedupe_key, token)

        {{:ok, token}, next_state}

      {{:error, :circuit_open}, circuit} ->
        {{:error, :circuit_open}, %{state | circuit: circuit}}
    end
  end

  defp finish_operation(server, token, result) do
    Agent.get_and_update(server, fn state ->
      case Map.pop(state.pending_operations, token) do
        {nil, _pending_operations} ->
          {{:error, :operation_not_found}, state}

        {pending_operation, pending_operations} ->
          next_state =
            state
            |> Map.put(:pending_operations, pending_operations)
            |> maybe_delete_pending_dedupe_key(pending_operation.dedupe_key)
            |> apply_operation_result(pending_operation, result)

          {result, next_state}
      end
    end)
  end

  defp apply_operation_result(state, pending_operation, {:ok, receipt}) do
    state =
      %{state | circuit: BridgeCircuit.record_success(state.circuit, pending_operation.scope_key)}

    case pending_operation.dedupe_key do
      nil -> state
      dedupe_key -> put_in(state, [:receipts_by_dedupe_key, dedupe_key], receipt)
    end
  end

  defp apply_operation_result(state, pending_operation, {:error, _reason}) do
    %{state | circuit: BridgeCircuit.record_failure(state.circuit, pending_operation.scope_key)}
  end

  defp maybe_put_pending_dedupe_key(state, nil, _token), do: state

  defp maybe_put_pending_dedupe_key(state, dedupe_key, token) do
    put_in(state, [:pending_dedupe_keys, dedupe_key], token)
  end

  defp maybe_delete_pending_dedupe_key(state, nil), do: state

  defp maybe_delete_pending_dedupe_key(state, dedupe_key) do
    %{state | pending_dedupe_keys: Map.delete(state.pending_dedupe_keys, dedupe_key)}
  end
end

defmodule Citadel.DomainSurface.Wave22FaultSupport.RequestSubmissionSurface do
  @moduledoc false

  @behaviour Citadel.DomainSurface.Adapters.CitadelAdapter.RequestSubmission

  alias Citadel.DomainSurface.Adapters.CitadelAdapter.RequestContext
  alias Citadel.DomainSurface.Wave22FaultSupport

  @impl true
  def submit_envelope(_envelope, %RequestContext{} = request_context, opts) do
    agent = Keyword.fetch!(opts, :agent)

    case Wave22FaultSupport.socket_round_trip(
           :request_submission,
           request_context.request_id,
           Keyword.put_new(opts, :dedupe_key, request_context.idempotency_key),
           fn ->
             continuity_revision =
               Wave22FaultSupport.next_semantic_submit_revision(
                 agent,
                 request_context.idempotency_key
               )

             Wave22FaultSupport.accepted_attrs(request_context, continuity_revision)
           end
         ) do
      {:ok, accepted_attrs} -> {:accepted, accepted_attrs}
      {:duplicate, accepted_attrs} -> {:accepted, accepted_attrs}
      {:error, reason} -> {:error, reason}
    end
  end
end

defmodule Citadel.DomainSurface.Wave22FaultSupport.QuerySurface do
  @moduledoc false

  @behaviour Citadel.DomainSurface.Adapters.CitadelAdapter.QuerySurface

  alias Citadel.DomainSurface.Wave22FaultSupport

  @impl true
  def fetch_runtime_observation(query, opts) do
    Wave22FaultSupport.socket_round_trip(
      :query_surface,
      query_request_id(query),
      Keyword.put(opts, :dedupe_key, nil),
      fn ->
        %{
          observation_id: "obs/#{query_request_id(query)}",
          request_id: Map.get(query, :request_id, Map.get(query, "request_id", "req-default")),
          session_id:
            Map.get(query, :session_id, Map.get(query, "session_id", "session-default")),
          signal_id: "sig/#{query_request_id(query)}",
          signal_cursor: "cursor/#{query_request_id(query)}",
          runtime_ref_id: "runtime/#{query_request_id(query)}",
          event_kind: "execution_event",
          event_at: ~U[2026-04-10 10:00:00Z],
          status: "ok",
          output: %{"result" => "ok"},
          artifacts: [],
          payload: %{},
          subject_ref: %{kind: :run, id: "run/#{query_request_id(query)}"},
          evidence_refs: [],
          governance_refs: [],
          extensions: %{}
        }
      end
    )
    |> normalize_result()
  end

  @impl true
  def fetch_boundary_session(query, opts) do
    Wave22FaultSupport.socket_round_trip(
      :query_surface,
      query_request_id(query),
      Keyword.put(opts, :dedupe_key, nil),
      fn -> Wave22FaultSupport.boundary_session_descriptor(Map.new(query)) end
    )
    |> normalize_result()
  end

  defp normalize_result({:ok, result}), do: {:ok, result}
  defp normalize_result({:duplicate, result}), do: {:ok, result}
  defp normalize_result({:error, reason}), do: {:error, reason}

  defp query_request_id(query) do
    Map.get(query, :target_id, Map.get(query, "target_id", "query-default"))
  end
end

defmodule Citadel.DomainSurface.Wave22FaultSupport.MaintenanceSurface do
  @moduledoc false

  @behaviour Citadel.DomainSurface.Adapters.CitadelAdapter.MaintenanceSurface

  alias Citadel.DomainSurface.Adapters.CitadelAdapter.RequestContext
  alias Citadel.DomainSurface.Wave22FaultSupport

  @impl true
  def inspect_dead_letter(entry_id, %RequestContext{} = request_context, opts) do
    opts
    |> Keyword.put_new(:dedupe_key, request_context.request_id)
    |> admin_round_trip(request_context.request_id, fn ->
      Wave22FaultSupport.maintenance_result(
        :inspect_dead_letter,
        request_context,
        %{entry_id: entry_id}
      )
    end)
  end

  @impl true
  def clear_dead_letter(entry_id, override_reason, %RequestContext{} = request_context, opts) do
    opts
    |> Keyword.put_new(:dedupe_key, request_context.request_id)
    |> admin_round_trip(request_context.request_id, fn ->
      Wave22FaultSupport.maintenance_result(
        :clear_dead_letter,
        request_context,
        %{entry_id: entry_id, override_reason: override_reason}
      )
    end)
  end

  @impl true
  def retry_dead_letter(entry_id, override_reason, %RequestContext{} = request_context, opts) do
    opts
    |> Keyword.put_new(:dedupe_key, request_context.request_id)
    |> admin_round_trip(request_context.request_id, fn ->
      Wave22FaultSupport.maintenance_result(
        :retry_dead_letter,
        request_context,
        %{entry_id: entry_id, override_reason: override_reason}
      )
      |> Map.put(:retry_opts, Keyword.get(opts, :retry_opts, []))
    end)
  end

  @impl true
  def replace_dead_letter(
        entry_id,
        replacement_entry,
        override_reason,
        %RequestContext{} = request_context,
        opts
      ) do
    opts
    |> Keyword.put_new(:dedupe_key, request_context.request_id)
    |> admin_round_trip(request_context.request_id, fn ->
      Wave22FaultSupport.maintenance_result(
        :replace_dead_letter,
        request_context,
        %{entry_id: entry_id, override_reason: override_reason}
      )
      |> Map.put(:replacement_entry, replacement_entry)
    end)
  end

  @impl true
  def recover_dead_letters(selector, operation, %RequestContext{} = request_context, opts) do
    opts
    |> Keyword.put_new(:dedupe_key, request_context.request_id)
    |> admin_round_trip(request_context.request_id, fn ->
      %{
        selector: selector,
        recovery_operation: operation,
        affected_count: 1,
        request_id: request_context.request_id,
        trace_id: request_context.trace_id
      }
    end)
  end

  defp admin_round_trip(opts, request_id, on_success) do
    case Wave22FaultSupport.socket_round_trip(
           :maintenance_surface,
           request_id,
           opts,
           on_success
         ) do
      {:ok, result} -> {:ok, result}
      {:duplicate, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end
end

defmodule Citadel.DomainSurface.Wave22FaultSupport.ExternalIntegrationAdapter do
  @moduledoc false

  @behaviour Citadel.DomainSurface.Ports.ExternalIntegration

  alias Citadel.DomainSurface.{Admin, Command, Error, Query}
  alias Citadel.DomainSurface.Wave22FaultSupport

  @impl true
  def dispatch_command(%Command{} = command) do
    {:error, Error.not_configured(:external_integration, operation: {:command, command.name})}
  end

  @impl true
  def dispatch_command(%Admin{} = admin) do
    {:error, Error.not_configured(:external_integration, operation: {:admin, admin.name})}
  end

  @impl true
  def dispatch_command(%Command{} = command, opts) do
    case Wave22FaultSupport.socket_round_trip(
           :external_integration,
           command.idempotency_key,
           Keyword.put_new(opts, :dedupe_key, command.idempotency_key),
           fn -> Wave22FaultSupport.external_result(command) end
         ) do
      {:ok, result} ->
        {:ok, result}

      {:duplicate, result} ->
        {:ok, result}

      {:error, reason} ->
        {:error,
         Wave22FaultSupport.configuration_error(
           :external_integration,
           reason,
           command.trace_id,
           command.route.name
         )}
    end
  end

  def dispatch_command(%Admin{} = admin, _opts) do
    {:error, Error.not_configured(:external_integration, operation: {:admin, admin.name})}
  end

  @impl true
  def run_query(%Query{} = query) do
    {:error, Error.not_configured(:external_integration, operation: {:query, query.name})}
  end

  @impl true
  def run_query(%Query{} = query, _opts) do
    run_query(query)
  end
end

defmodule Citadel.DomainSurface.FaultInjectionAndOperabilityTest do
  use ExUnit.Case, async: false

  alias Citadel.TestSupport.HalfOpenSocketServer
  alias Citadel.TestSupport.ToxiproxyHarness
  alias Citadel.DomainSurface.Adapters.CitadelAdapter
  alias Citadel.DomainSurface.Adapters.CitadelAdapter.Accepted
  alias Citadel.DomainSurface.Error
  alias Citadel.DomainSurface.Examples.ArticlePublishing
  alias Citadel.DomainSurface.Examples.ProvingGround
  alias Citadel.DomainSurface.Wave22FaultSupport
  alias Citadel.DomainSurface.Wave22FaultSupport.ExternalIntegrationAdapter
  alias Citadel.DomainSurface.Wave22FaultSupport.MaintenanceSurface
  alias Citadel.DomainSurface.Wave22FaultSupport.QuerySurface
  alias Citadel.DomainSurface.Wave22FaultSupport.RequestSubmissionSurface

  @proxy_name "citadel_nginx"

  setup do
    if wave22_enabled?() do
      case ToxiproxyHarness.availability_result!("Citadel.DomainSurface Wave 22 fault injection") do
        :ok -> :ok
        {:skip, _reason} -> :ok
      end

      ToxiproxyHarness.ensure_proxy!()
    end

    on_exit(fn ->
      if wave22_enabled?() do
        ToxiproxyHarness.ensure_proxy!()
      end
    end)

    :ok
  end

  test "Citadel command latency runs through the canonical harness and keeps retries bounded" do
    run_wave22(fn ->
      env = start_socket_env!()

      runtime_opts =
        citadel_runtime_opts(env, request_submission_opts: socket_opts(env, timeout: 1_000))

      ToxiproxyHarness.add_toxic!(@proxy_name, "latency", "latency", %{"latency" => 400})

      {{:ok, %Accepted{} = accepted}, delayed_ms} =
        ToxiproxyHarness.measure_ms(fn ->
          ArticlePublishing.publish_article(
            %{article_id: "article-latency-1"},
            idempotency_key: "pub-latency-1",
            context: %{trace_id: "trace/pub-latency-1"},
            kernel_runtime: {CitadelAdapter, runtime_opts}
          )
        end)

      assert delayed_ms >= 350
      assert accepted.request_id == "pub-latency-1"
      assert Wave22FaultSupport.attempt_count(env.agent, :request_submission) == 1
      assert Wave22FaultSupport.worker_task_starts(env.agent) == 1
      assert Wave22FaultSupport.semantic_submit_count(env.agent, "pub-latency-1") == 1

      ToxiproxyHarness.ensure_proxy!()

      {{:ok, %Accepted{} = recovered}, recovered_ms} =
        ToxiproxyHarness.measure_ms(fn ->
          ArticlePublishing.publish_article(
            %{article_id: "article-latency-2"},
            idempotency_key: "pub-latency-2",
            context: %{trace_id: "trace/pub-latency-2"},
            kernel_runtime: {CitadelAdapter, runtime_opts}
          )
        end)

      assert recovered.request_id == "pub-latency-2"
      assert recovered_ms < 150
      assert Wave22FaultSupport.attempt_count(env.agent, :request_submission) == 2
    end)
  end

  test "Citadel command connection drops fail explicitly without hidden retries" do
    run_wave22(fn ->
      env = start_socket_env!()
      runtime_opts = citadel_runtime_opts(env)

      ToxiproxyHarness.set_enabled!(@proxy_name, false)

      {{:error, %Error{} = error}, elapsed_ms} =
        ToxiproxyHarness.measure_ms(fn ->
          ArticlePublishing.publish_article(
            %{article_id: "article-drop-1"},
            idempotency_key: "pub-drop-1",
            context: %{trace_id: "trace/pub-drop-1"},
            kernel_runtime: {CitadelAdapter, runtime_opts}
          )
        end)

      assert elapsed_ms < 150

      assert_configuration_error(
        error,
        :request_submission,
        :connection_dropped,
        "trace/pub-drop-1"
      )

      assert Wave22FaultSupport.attempt_count(env.agent, :request_submission) == 1
      assert Wave22FaultSupport.semantic_submit_count(env.agent, "pub-drop-1") == 0
    end)
  end

  test "Citadel half-open command hangs open the circuit and then fast-fail before the worker pool saturates" do
    run_wave22(fn ->
      env =
        start_socket_env!(
          policy_overrides: %{failure_threshold: 2},
          max_children: 1
        )

      server = start_supervised!(HalfOpenSocketServer)

      runtime_opts =
        citadel_runtime_opts(
          env,
          request_submission_opts:
            socket_opts(env,
              url: HalfOpenSocketServer.url(server),
              timeout: 200
            )
        )

      {{:error, %Error{} = first_error}, first_ms} =
        ToxiproxyHarness.measure_ms(fn ->
          ArticlePublishing.publish_article(
            %{article_id: "article-half-open-1"},
            idempotency_key: "pub-half-open-1",
            context: %{trace_id: "trace/pub-half-open-1"},
            kernel_runtime: {CitadelAdapter, runtime_opts}
          )
        end)

      assert first_ms >= 180

      assert_configuration_error(
        first_error,
        :request_submission,
        :timeout,
        "trace/pub-half-open-1"
      )

      {{:error, %Error{} = second_error}, second_ms} =
        ToxiproxyHarness.measure_ms(fn ->
          ArticlePublishing.publish_article(
            %{article_id: "article-half-open-2"},
            idempotency_key: "pub-half-open-2",
            context: %{trace_id: "trace/pub-half-open-2"},
            kernel_runtime: {CitadelAdapter, runtime_opts}
          )
        end)

      assert second_ms >= 180

      assert_configuration_error(
        second_error,
        :request_submission,
        :timeout,
        "trace/pub-half-open-2"
      )

      {{:error, %Error{} = third_error}, third_ms} =
        ToxiproxyHarness.measure_ms(fn ->
          ArticlePublishing.publish_article(
            %{article_id: "article-half-open-3"},
            idempotency_key: "pub-half-open-3",
            context: %{trace_id: "trace/pub-half-open-3"},
            kernel_runtime: {CitadelAdapter, runtime_opts}
          )
        end)

      assert third_ms < 50

      assert_configuration_error(
        third_error,
        :request_submission,
        :circuit_open,
        "trace/pub-half-open-3"
      )

      burst_results =
        1..3
        |> Task.async_stream(
          fn index ->
            ArticlePublishing.publish_article(
              %{article_id: "article-fast-fail-#{index}"},
              idempotency_key: "pub-fast-fail-#{index}",
              context: %{trace_id: "trace/pub-fast-fail-#{index}"},
              kernel_runtime: {CitadelAdapter, runtime_opts}
            )
          end,
          ordered: false,
          timeout: 1_000,
          max_concurrency: 3
        )
        |> Enum.map(fn {:ok, result} -> result end)

      assert Enum.all?(burst_results, fn
               {:error, %Error{} = error} ->
                 error.details[:reason] == :circuit_open and
                   error.details[:component] == :request_submission

               _other ->
                 false
             end)

      assert Wave22FaultSupport.attempt_count(env.agent, :request_submission) == 2
      assert Wave22FaultSupport.worker_task_starts(env.agent) == 2
      assert Supervisor.count_children(env.worker_supervisor).active == 0
    end)
  end

  test "ambiguous Citadel submission failures stay explicit and do not duplicate semantic submits" do
    run_wave22(fn ->
      env = start_socket_env!()

      runtime_opts =
        citadel_runtime_opts(
          env,
          request_submission_opts: socket_opts(env, ambiguous_once?: true)
        )

      assert {:error, %Error{} = first_error} =
               ArticlePublishing.publish_article(
                 %{article_id: "article-ambiguous-1"},
                 idempotency_key: "pub-ambiguous-1",
                 context: %{trace_id: "trace/pub-ambiguous-1"},
                 kernel_runtime: {CitadelAdapter, runtime_opts}
               )

      assert_configuration_error(
        first_error,
        :request_submission,
        :ambiguous_submit,
        "trace/pub-ambiguous-1"
      )

      assert Wave22FaultSupport.attempt_count(env.agent, :request_submission) == 1
      assert Wave22FaultSupport.worker_task_starts(env.agent) == 1
      assert Wave22FaultSupport.semantic_submit_count(env.agent, "pub-ambiguous-1") == 1

      assert {:ok, %Accepted{} = accepted} =
               ArticlePublishing.publish_article(
                 %{article_id: "article-ambiguous-1"},
                 idempotency_key: "pub-ambiguous-1",
                 context: %{trace_id: "trace/pub-ambiguous-1"},
                 kernel_runtime: {CitadelAdapter, runtime_opts}
               )

      assert accepted.request_id == "pub-ambiguous-1"
      assert Wave22FaultSupport.attempt_count(env.agent, :request_submission) == 1
      assert Wave22FaultSupport.worker_task_starts(env.agent) == 1
      assert Wave22FaultSupport.semantic_submit_count(env.agent, "pub-ambiguous-1") == 1
    end)
  end

  test "Citadel queries fail explicitly under downstream degradation" do
    run_wave22(fn ->
      env = start_socket_env!()
      runtime_opts = citadel_runtime_opts(env)

      ToxiproxyHarness.set_enabled!(@proxy_name, false)

      {{:error, %Error{} = error}, elapsed_ms} =
        ToxiproxyHarness.measure_ms(fn ->
          ArticlePublishing.publication_status(
            %{article_id: "article-query-drop-1"},
            context: %{trace_id: "trace/query-drop-1"},
            kernel_runtime: {CitadelAdapter, runtime_opts}
          )
        end)

      assert elapsed_ms < 150
      assert_configuration_error(error, :query_surface, :connection_dropped, "trace/query-drop-1")
      assert Wave22FaultSupport.attempt_count(env.agent, :query_surface) == 1
    end)
  end

  test "Citadel admin surfaces fail explicitly and observably under degradation" do
    run_wave22(fn ->
      env = start_socket_env!()
      runtime_opts = citadel_runtime_opts(env)

      ToxiproxyHarness.set_enabled!(@proxy_name, false)

      assert {:error, %Error{} = error} =
               Citadel.DomainSurface.maintain(
                 ProvingGround.AdminCommands.InspectDeadLetter,
                 %{entry_id: "entry-admin-drop-1"},
                 idempotency_key: "admin-drop-1",
                 context: %{trace_id: "trace/admin-drop-1"},
                 kernel_runtime: {CitadelAdapter, runtime_opts}
               )

      assert_configuration_error(
        error,
        :maintenance_surface,
        :connection_dropped,
        "trace/admin-drop-1"
      )

      assert Wave22FaultSupport.attempt_count(env.agent, :maintenance_surface) == 1
    end)
  end

  test "the optional lower adapter sees the same latency fault class with bounded attempts" do
    run_wave22(fn ->
      env = start_socket_env!()
      external_integration = {ExternalIntegrationAdapter, socket_opts(env, timeout: 1_000)}

      ToxiproxyHarness.add_toxic!(@proxy_name, "latency", "latency", %{"latency" => 400})

      {{:ok, result}, delayed_ms} =
        ToxiproxyHarness.measure_ms(fn ->
          Citadel.DomainSurface.submit(
            ProvingGround.Commands.RecordOperatorEvidence,
            %{evidence_id: "evidence-latency-1"},
            idempotency_key: "ext-latency-1",
            context: %{trace_id: "trace/ext-latency-1"},
            external_integration: external_integration
          )
        end)

      assert delayed_ms >= 350
      assert result.lower_seam == :external_integration
      assert result.idempotency_key == "ext-latency-1"
      assert Wave22FaultSupport.attempt_count(env.agent, :external_integration) == 1
    end)
  end

  test "the optional lower adapter connection drop is explicit and retry-free" do
    run_wave22(fn ->
      env = start_socket_env!()
      external_integration = {ExternalIntegrationAdapter, socket_opts(env)}

      ToxiproxyHarness.set_enabled!(@proxy_name, false)

      {{:error, %Error{} = error}, elapsed_ms} =
        ToxiproxyHarness.measure_ms(fn ->
          Citadel.DomainSurface.submit(
            ProvingGround.Commands.RecordOperatorEvidence,
            %{evidence_id: "evidence-drop-1"},
            idempotency_key: "ext-drop-1",
            context: %{trace_id: "trace/ext-drop-1"},
            external_integration: external_integration
          )
        end)

      assert elapsed_ms < 150

      assert_configuration_error(
        error,
        :external_integration,
        :connection_dropped,
        "trace/ext-drop-1"
      )

      assert Wave22FaultSupport.attempt_count(env.agent, :external_integration) == 1
    end)
  end

  test "the optional lower adapter half-open path times out twice and then fast-fails behind an open circuit" do
    run_wave22(fn ->
      env =
        start_socket_env!(
          policy_overrides: %{failure_threshold: 2},
          max_children: 1
        )

      server = start_supervised!(HalfOpenSocketServer)

      external_integration =
        {ExternalIntegrationAdapter,
         socket_opts(env,
           url: HalfOpenSocketServer.url(server),
           timeout: 200
         )}

      {{:error, %Error{} = first_error}, first_ms} =
        ToxiproxyHarness.measure_ms(fn ->
          Citadel.DomainSurface.submit(
            ProvingGround.Commands.RecordOperatorEvidence,
            %{evidence_id: "evidence-half-open-1"},
            idempotency_key: "ext-half-open-1",
            context: %{trace_id: "trace/ext-half-open-1"},
            external_integration: external_integration
          )
        end)

      assert first_ms >= 180

      assert_configuration_error(
        first_error,
        :external_integration,
        :timeout,
        "trace/ext-half-open-1"
      )

      {{:error, %Error{} = second_error}, second_ms} =
        ToxiproxyHarness.measure_ms(fn ->
          Citadel.DomainSurface.submit(
            ProvingGround.Commands.RecordOperatorEvidence,
            %{evidence_id: "evidence-half-open-2"},
            idempotency_key: "ext-half-open-2",
            context: %{trace_id: "trace/ext-half-open-2"},
            external_integration: external_integration
          )
        end)

      assert second_ms >= 180

      assert_configuration_error(
        second_error,
        :external_integration,
        :timeout,
        "trace/ext-half-open-2"
      )

      {{:error, %Error{} = third_error}, third_ms} =
        ToxiproxyHarness.measure_ms(fn ->
          Citadel.DomainSurface.submit(
            ProvingGround.Commands.RecordOperatorEvidence,
            %{evidence_id: "evidence-half-open-3"},
            idempotency_key: "ext-half-open-3",
            context: %{trace_id: "trace/ext-half-open-3"},
            external_integration: external_integration
          )
        end)

      assert third_ms < 50

      assert_configuration_error(
        third_error,
        :external_integration,
        :circuit_open,
        "trace/ext-half-open-3"
      )

      assert Wave22FaultSupport.attempt_count(env.agent, :external_integration) == 2
      assert Wave22FaultSupport.worker_task_starts(env.agent) == 2
      assert Supervisor.count_children(env.worker_supervisor).active == 0
    end)
  end

  defp start_socket_env!(opts \\ []) do
    agent =
      start_supervised!(%{
        id: make_ref(),
        start: {Agent, :start_link, [fn -> Wave22FaultSupport.initial_probe_state() end]}
      })

    policy =
      opts
      |> Keyword.get(:policy_overrides, %{})
      |> Wave22FaultSupport.bridge_policy()

    bridge_state =
      start_supervised!(%{
        id: make_ref(),
        start: {Wave22FaultSupport, :bridge_state, [policy]}
      })

    worker_supervisor =
      start_supervised!(%{
        id: make_ref(),
        start:
          {Task.Supervisor, :start_link, [[max_children: Keyword.get(opts, :max_children, 4)]]}
      })

    %{agent: agent, bridge_state: bridge_state, worker_supervisor: worker_supervisor}
  end

  defp citadel_runtime_opts(env, overrides \\ []) do
    [
      request_submission: RequestSubmissionSurface,
      request_submission_opts: socket_opts(env),
      query_surface: QuerySurface,
      query_surface_opts: socket_opts(env),
      maintenance_surface: MaintenanceSurface,
      maintenance_surface_opts: socket_opts(env),
      context_defaults: %{
        tenant_id: "tenant-default",
        actor_id: "actor-default",
        session_id: "session-default",
        environment: "dev"
      }
    ]
    |> Keyword.merge(overrides)
  end

  defp socket_opts(env, overrides \\ []) do
    [
      agent: env.agent,
      bridge_state: env.bridge_state,
      worker_supervisor: env.worker_supervisor,
      timeout: 500
    ]
    |> Keyword.merge(overrides)
  end

  defp assert_configuration_error(error, component, reason, trace_id) do
    assert error.category == :configuration
    assert error.code == :not_configured
    assert error.trace_id == trace_id
    assert error.details[:component] == component
    assert error.details[:reason] == reason
  end

  defp run_wave22(fun) when is_function(fun, 0) do
    if wave22_enabled?(), do: fun.(), else: :ok
  end

  defp wave22_enabled? do
    System.get_env("CITADEL_REQUIRE_TOXIPROXY") == "1" or
      System.get_env("CITADEL_DOMAIN_SURFACE_REQUIRE_TOXIPROXY") == "1"
  end
end
