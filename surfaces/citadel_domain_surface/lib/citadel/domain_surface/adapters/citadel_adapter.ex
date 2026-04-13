defmodule Citadel.DomainSurface.Adapters.CitadelAdapter do
  @moduledoc """
  Narrow typed adapter from the Domain boundary into explicit Citadel seams.

  The adapter accepts semantic Domain commands, queries, and bounded admin
  operations; builds structured Citadel ingress or read-surface queries; and
  translates Citadel rejections into the frozen Domain error vocabulary without
  leaking Citadel runtime topology into the public Domain API.
  """

  @behaviour Citadel.DomainSurface.Ports.KernelRuntime

  alias Citadel.BoundarySessionDescriptor.V1, as: BoundarySessionDescriptorV1
  alias Citadel.IntentEnvelope

  alias Citadel.IntentEnvelope.{
    Constraints,
    DesiredOutcome,
    RiskHint,
    ScopeSelector,
    SuccessCriterion,
    TargetHint
  }

  alias Citadel.PlanHints
  alias Citadel.PlanHints.CandidateStep

  alias Citadel.ResolutionProvenance
  alias Citadel.RuntimeObservation

  alias Citadel.DomainSurface.Adapters.CitadelAdapter.{
    Accepted,
    Config,
    PayloadMigration,
    RequestContext
  }

  alias Citadel.DomainSurface.{Admin, Command, Error, Query}

  @type runtime_opts :: keyword()
  @type query_payload :: %{optional(atom() | String.t()) => term()}
  @type admin_payload :: %{optional(atom()) => term()}
  @type trace_lineage :: %{trace_id: String.t(), origin: RequestContext.trace_origin()}
  @type command_result :: {:ok, Accepted.t()} | {:error, Error.t()}
  @type admin_result :: {:ok, admin_payload()} | {:error, Error.t()}
  @type query_result ::
          {:ok, BoundarySessionDescriptorV1.t() | RuntimeObservation.t() | query_payload()}
          | {:error, Error.t()}

  @spec dispatch_command(Command.t()) :: command_result()
  @spec dispatch_command(Admin.t()) :: admin_result()
  @impl true
  def dispatch_command(%Command{} = command) do
    {:error, Error.not_configured(:citadel_adapter, operation: {:command, command.name})}
  end

  def dispatch_command(%Admin{} = admin) do
    {:error, Error.not_configured(:citadel_adapter, operation: {:admin, admin.name})}
  end

  @doc """
  Returns the canonical typed runtime option set for the public Citadel adapter.
  """
  @spec runtime_opts(keyword()) :: runtime_opts()
  def runtime_opts(opts \\ []) when is_list(opts) do
    [
      id_port: Keyword.get(opts, :id_port),
      request_submission:
        Keyword.get(
          opts,
          :request_submission,
          Citadel.DomainSurface.Adapters.CitadelAdapter.HostIngressSurface
        ),
      request_submission_opts: Keyword.get(opts, :request_submission_opts, []),
      query_surface:
        Keyword.get(
          opts,
          :query_surface,
          Citadel.DomainSurface.Adapters.CitadelAdapter.QueryBridgeSurface
        ),
      query_surface_opts: Keyword.get(opts, :query_surface_opts, []),
      maintenance_surface:
        Keyword.get(
          opts,
          :maintenance_surface,
          Citadel.DomainSurface.Adapters.CitadelAdapter.SessionDirectoryMaintenance
        ),
      maintenance_surface_opts: Keyword.get(opts, :maintenance_surface_opts, []),
      context_defaults: Keyword.get(opts, :context_defaults, %{})
    ]
  end

  @spec dispatch_command(Command.t(), runtime_opts()) :: command_result()
  @spec dispatch_command(Admin.t(), runtime_opts()) :: admin_result()
  @impl true
  def dispatch_command(%Command{} = command, opts) when is_list(opts) do
    with {:ok, config} <- load_config(opts),
         {:ok, trace_lineage} <- resolve_trace_lineage(command.trace_id, config),
         {:ok, request_context} <- build_command_request_context(command, config, trace_lineage),
         {:ok, envelope} <- build_command_envelope(command, request_context),
         {:ok, request_submission} <-
           fetch_required_surface(config.request_submission, :request_submission, command),
         submission_opts <-
           Keyword.put(config.request_submission_opts, :command_name, command.name) do
      case request_submission.submit_envelope(envelope, request_context, submission_opts) do
        {:accepted, accepted_attrs} ->
          normalize_accepted_result(accepted_attrs, request_context, command)

        {:rejected, rejection} ->
          {:error,
           Error.from_rejection(
             rejection,
             trace_id: request_context.trace_id,
             request_name: command.name,
             route: command.route.name
           )}

        {:error, reason} ->
          {:error,
           downstream_error(
             :request_submission,
             "citadel request submission failed",
             reason,
             request_context.trace_id,
             command.route.name
           )}
      end
    end
  end

  def dispatch_command(%Admin{} = admin, opts) when is_list(opts) do
    with {:ok, config} <- load_config(opts),
         {:ok, trace_lineage} <- resolve_trace_lineage(admin.trace_id, config),
         {:ok, request_context} <- build_admin_request_context(admin, config, trace_lineage),
         {:ok, maintenance_surface} <-
           fetch_required_surface(config.maintenance_surface, :maintenance_surface, admin),
         {:ok, result} <-
           dispatch_admin_operation(
             admin,
             maintenance_surface,
             request_context,
             Keyword.put(config.maintenance_surface_opts, :admin_name, admin.name)
           ),
         {:ok, normalized_result} <-
           normalize_admin_result(result, admin.route.operation, request_context, admin) do
      {:ok, normalized_result}
    else
      {:error, %Error{} = error} ->
        {:error, error}

      {:error, reason} ->
        {:error,
         downstream_error(
           :maintenance_surface,
           "citadel maintenance surface failed",
           reason,
           admin.trace_id,
           admin.route.name
         )}
    end
  end

  @spec run_query(Query.t()) :: query_result()
  @impl true
  def run_query(%Query{} = query) do
    {:error, Error.not_configured(:citadel_adapter, operation: {:query, query.name})}
  end

  @spec run_query(Query.t(), runtime_opts()) :: query_result()
  @impl true
  def run_query(%Query{} = query, opts) when is_list(opts) do
    with {:ok, config} <- load_config(opts),
         {:ok, trace_lineage} <- resolve_trace_lineage(query.trace_id, config),
         {:ok, query_surface} <-
           fetch_required_surface(config.query_surface, :query_surface, query),
         {:ok, surface, query_map} <- build_query(query, config, trace_lineage),
         {:ok, result} <-
           dispatch_query_surface(query_surface, surface, query_map, config.query_surface_opts) do
      normalize_query_result(surface, result, query)
    else
      {:error, %Error{} = error} ->
        {:error, error}

      {:error, reason} ->
        {:error,
         downstream_error(
           :query_surface,
           "citadel query surface failed",
           reason,
           query.trace_id,
           query.route.name
         )}
    end
  end

  defp load_config(opts) do
    opts
    |> Keyword.get(:config, opts)
    |> Config.new()
  end

  defp resolve_trace_lineage(trace_id, _config) when is_binary(trace_id) and trace_id != "" do
    {:ok, %{trace_id: trace_id, origin: :host}}
  end

  defp resolve_trace_lineage(_trace_id, %Config{id_port: nil}) do
    {:error,
     Error.configuration(
       :not_configured,
       "citadel adapter requires id_port to mint trace_id when the host omits one",
       component: :id_port
     )}
  end

  defp resolve_trace_lineage(_trace_id, %Config{id_port: id_port}) do
    case id_port.new_id(:trace) do
      {:ok, minted_trace_id} when is_binary(minted_trace_id) and minted_trace_id != "" ->
        {:ok, %{trace_id: minted_trace_id, origin: :domain_minted}}

      {:ok, invalid_value} ->
        {:error,
         Error.validation(
           :invalid_trace_id,
           "citadel id_port returned an invalid trace_id",
           actual: inspect(invalid_value)
         )}

      {:error, reason} ->
        {:error,
         Error.configuration(
           :not_configured,
           "citadel id_port failed to mint trace_id",
           component: :id_port,
           reason: inspect(reason)
         )}
    end
  end

  defp build_command_request_context(%Command{} = command, %Config{} = config, trace_lineage) do
    merged_context = merged_context(config.context_defaults, command.context)

    request_context =
      RequestContext.new!(%{
        request_id: command.idempotency_key,
        session_id: context_value(merged_context, :session_id),
        tenant_id: context_value(merged_context, :tenant_id),
        actor_id: context_value(merged_context, :actor_id),
        trace_id: trace_lineage.trace_id,
        trace_origin: trace_lineage.origin,
        idempotency_key: command.idempotency_key,
        host_request_id: context_value(merged_context, :request_id),
        environment: context_value(merged_context, :environment),
        policy_epoch: context_integer(merged_context, :policy_epoch, 0),
        metadata_keys: bounded_metadata_keys(command.metadata)
      })

    with :ok <- require_context_field(request_context.session_id, :session_id),
         :ok <- require_context_field(request_context.tenant_id, :tenant_id),
         :ok <- require_context_field(request_context.actor_id, :actor_id) do
      {:ok, request_context}
    end
  rescue
    error in ArgumentError ->
      {:error,
       Error.validation(:invalid_context, Exception.message(error), request_name: command.name)}
  end

  defp build_admin_request_context(%Admin{} = admin, %Config{} = config, trace_lineage) do
    merged_context = merged_context(config.context_defaults, admin.context)

    request_context =
      RequestContext.new!(%{
        request_id: admin.idempotency_key,
        session_id: context_value(merged_context, :session_id),
        tenant_id: context_value(merged_context, :tenant_id),
        actor_id: context_value(merged_context, :actor_id),
        trace_id: trace_lineage.trace_id,
        trace_origin: trace_lineage.origin,
        idempotency_key: admin.idempotency_key,
        host_request_id: context_value(merged_context, :request_id),
        environment: context_value(merged_context, :environment),
        policy_epoch: context_integer(merged_context, :policy_epoch, 0),
        metadata_keys: bounded_metadata_keys(admin.metadata)
      })

    {:ok, request_context}
  rescue
    error in ArgumentError ->
      {:error,
       Error.validation(:invalid_context, Exception.message(error), request_name: admin.name)}
  end

  defp build_command_envelope(%Command{} = command, %RequestContext{} = request_context) do
    with {:ok, mapping} <- fetch_route_mapping(command.route.metadata, :citadel_command, command),
         {:ok, scope_kind} <- fetch_required_mapping_string(mapping, :scope_kind, command),
         {:ok, capability} <- fetch_required_mapping_string(mapping, :capability, command),
         {:ok, result_kind} <- fetch_required_mapping_string(mapping, :result_kind, command),
         {:ok, target_kind} <- fetch_optional_mapping_string(mapping, :target_kind, scope_kind),
         {:ok, scope_id} <- fetch_field_value(command.input, mapping, :scope_id_field, command),
         {:ok, workspace_root} <-
           fetch_optional_field_value(command.input, mapping, :workspace_root_field),
         {:ok, target_id} <-
           fetch_field_value(command.input, mapping, :target_id_field, command, scope_id),
         {:ok, boundary_requirement} <-
           fetch_mapping_atom(mapping, :boundary_requirement, :fresh_or_reuse, command),
         {:ok, boundary_class} <- fetch_optional_mapping_string(mapping, :boundary_class, nil),
         {:ok, service_id} <- fetch_optional_mapping_string(mapping, :service_id, nil),
         {:ok, risk_code} <- fetch_optional_mapping_string(mapping, :risk_code, "domain_request"),
         {:ok, risk_severity} <- fetch_mapping_atom(mapping, :risk_severity, :low, command),
         {:ok, review_required} <-
           fetch_mapping_boolean(mapping, :review_required, false, command),
         {:ok, success_metric} <-
           fetch_optional_mapping_string(mapping, :success_metric, "accepted"),
         {:ok, routing_tags} <- fetch_mapping_list(mapping, :routing_tags, []),
         {:ok, subject_selectors} <- fetch_mapping_list(mapping, :subject_selectors, []),
         {:ok, session_mode_preference} <-
           fetch_mapping_atom(mapping, :session_mode_preference, :attached, command),
         {:ok, coordination_mode_preference} <-
           fetch_mapping_atom(mapping, :coordination_mode_preference, :single_target, command),
         {:ok, plan_hints} <-
           build_plan_hints(mapping, command.input, request_context, capability, command) do
      provenance_extensions = provenance_extensions(command, request_context)

      {:ok,
       IntentEnvelope.new!(%{
         intent_envelope_id: "intent/#{command.name}/#{request_context.request_id}",
         scope_selectors: [
           ScopeSelector.new!(%{
             scope_kind: scope_kind,
             scope_id: scope_id,
             workspace_root: workspace_root,
             environment: request_context.environment,
             preference: :required,
             extensions: %{}
           })
         ],
         desired_outcome:
           DesiredOutcome.new!(%{
             outcome_kind: :invoke_capability,
             requested_capabilities: [capability],
             result_kind: result_kind,
             subject_selectors: subject_selectors,
             extensions: %{}
           }),
         constraints:
           Constraints.new!(%{
             boundary_requirement: boundary_requirement,
             allowed_boundary_classes: compact_optional(boundary_class),
             allowed_service_ids: compact_optional(service_id),
             forbidden_service_ids: [],
             max_steps: 1,
             review_required: review_required,
             extensions: %{}
           }),
         risk_hints: [
           RiskHint.new!(%{
             risk_code: risk_code,
             severity: risk_severity,
             requires_governance: review_required,
             extensions: %{}
           })
         ],
         success_criteria: [
           SuccessCriterion.new!(%{
             criterion_kind: :completion,
             metric: success_metric,
             target: %{"status" => "accepted"},
             required: true,
             extensions: %{}
           })
         ],
         target_hints: [
           TargetHint.new!(%{
             target_kind: target_kind,
             preferred_target_id: target_id,
             preferred_service_id: service_id,
             preferred_boundary_class: boundary_class,
             session_mode_preference: session_mode_preference,
             coordination_mode_preference: coordination_mode_preference,
             routing_tags: routing_tags,
             extensions: %{}
           })
         ],
         plan_hints: plan_hints,
         resolution_provenance:
           ResolutionProvenance.new!(%{
             source_kind: "citadel_domain_surface",
             resolver_kind: nil,
             resolver_version: nil,
             prompt_version: nil,
             policy_version: nil,
             confidence: 1.0,
             ambiguity_flags: [],
             raw_input_refs: [],
             raw_input_hashes: [],
             extensions: provenance_extensions
           }),
         extensions: %{"citadel_domain_surface" => provenance_extensions}
       })}
    end
  rescue
    error in ArgumentError ->
      {:error,
       Error.validation(:invalid_definition, Exception.message(error),
         request_name: command.name,
         route: command.route.name
       )}
  end

  defp build_query(%Query{} = query, %Config{} = config, trace_lineage) do
    merged_context = merged_context(config.context_defaults, query.context)

    with {:ok, mapping} <- fetch_route_mapping(query.route.metadata, :citadel_query, query),
         {:ok, surface} <- fetch_mapping_atom(mapping, :surface, nil, query),
         {:ok, downstream_scope} <-
           fetch_required_mapping_string(mapping, :downstream_scope, query) do
      query_map =
        %{
          downstream_scope: downstream_scope,
          trace_id: trace_lineage.trace_id,
          query_name: Atom.to_string(query.name)
        }
        |> maybe_put(:request_id, context_value(merged_context, :request_id))
        |> maybe_put(:session_id, context_value(merged_context, :session_id))
        |> maybe_put(:tenant_id, context_value(merged_context, :tenant_id))
        |> maybe_put(:target_id, optional_query_value(query.params, mapping, :target_id_field))
        |> maybe_put(
          :boundary_ref,
          optional_query_value(query.params, mapping, :boundary_ref_field)
        )
        |> maybe_put(
          :boundary_session_id,
          optional_query_value(query.params, mapping, :boundary_session_id_field)
        )
        |> maybe_put(:signal_id, optional_query_value(query.params, mapping, :signal_id_field))
        |> maybe_put(
          :signal_cursor,
          optional_query_value(query.params, mapping, :signal_cursor_field)
        )
        |> maybe_put(
          :runtime_ref_id,
          optional_query_value(query.params, mapping, :runtime_ref_id_field)
        )

      {:ok, surface, query_map}
    end
  end

  defp build_recover_dead_letters_request(%Admin{} = admin) do
    with {:ok, mapping} <- fetch_route_mapping(admin.route.metadata, :citadel_admin, admin),
         {:ok, selector} <-
           fetch_input_keyword(admin.input, mapping, :selector_field, :selector, admin),
         {:ok, operation} <- fetch_admin_operation(admin.input, mapping) do
      {:ok, selector, operation}
    end
  end

  defp dispatch_admin_operation(
         %Admin{route: %{operation: :inspect_dead_letter}} = admin,
         maintenance_surface,
         %RequestContext{} = request_context,
         opts
       ) do
    with {:ok, mapping} <- fetch_route_mapping(admin.route.metadata, :citadel_admin, admin),
         {:ok, entry_id} <- fetch_field_value(admin.input, mapping, :entry_id_field, admin) do
      maintenance_surface.inspect_dead_letter(entry_id, request_context, opts)
    end
  end

  defp dispatch_admin_operation(
         %Admin{route: %{operation: :clear_dead_letter}} = admin,
         maintenance_surface,
         %RequestContext{} = request_context,
         opts
       ) do
    with {:ok, mapping} <- fetch_route_mapping(admin.route.metadata, :citadel_admin, admin),
         {:ok, entry_id} <- fetch_field_value(admin.input, mapping, :entry_id_field, admin),
         {:ok, override_reason} <-
           fetch_field_value(admin.input, mapping, :override_reason_field, admin) do
      maintenance_surface.clear_dead_letter(entry_id, override_reason, request_context, opts)
    end
  end

  defp dispatch_admin_operation(
         %Admin{route: %{operation: :retry_dead_letter}} = admin,
         maintenance_surface,
         %RequestContext{} = request_context,
         opts
       ) do
    with {:ok, mapping} <- fetch_route_mapping(admin.route.metadata, :citadel_admin, admin),
         {:ok, entry_id} <- fetch_field_value(admin.input, mapping, :entry_id_field, admin),
         {:ok, override_reason} <-
           fetch_field_value(admin.input, mapping, :override_reason_field, admin),
         {:ok, retry_opts} <-
           fetch_optional_input_keyword(admin.input, mapping, :retry_opts_field) do
      maintenance_surface.retry_dead_letter(
        entry_id,
        override_reason,
        request_context,
        Keyword.put(opts, :retry_opts, retry_opts)
      )
    end
  end

  defp dispatch_admin_operation(
         %Admin{route: %{operation: :replace_dead_letter}} = admin,
         maintenance_surface,
         %RequestContext{} = request_context,
         opts
       ) do
    with {:ok, mapping} <- fetch_route_mapping(admin.route.metadata, :citadel_admin, admin),
         {:ok, entry_id} <- fetch_field_value(admin.input, mapping, :entry_id_field, admin),
         {:ok, override_reason} <-
           fetch_field_value(admin.input, mapping, :override_reason_field, admin),
         {:ok, replacement_entry} <-
           fetch_required_input_value(
             admin.input,
             mapping,
             :replacement_entry_field,
             :replacement_entry,
             admin
           ) do
      maintenance_surface.replace_dead_letter(
        entry_id,
        replacement_entry,
        override_reason,
        request_context,
        opts
      )
    end
  end

  defp dispatch_admin_operation(
         %Admin{route: %{operation: :recover_dead_letters}} = admin,
         maintenance_surface,
         %RequestContext{} = request_context,
         opts
       ) do
    with {:ok, selector, operation} <- build_recover_dead_letters_request(admin) do
      maintenance_surface.recover_dead_letters(selector, operation, request_context, opts)
    end
  end

  defp dispatch_admin_operation(%Admin{} = admin, _maintenance_surface, _request_context, _opts) do
    {:error,
     Error.validation(
       :invalid_definition,
       "unsupported citadel admin operation #{inspect(admin.route.operation)}",
       route: admin.route.name,
       request_name: admin.name
     )}
  end

  defp dispatch_query_surface(query_surface, :boundary_session, query_map, opts) do
    query_surface.fetch_boundary_session(query_map, opts)
  end

  defp dispatch_query_surface(query_surface, :runtime_observation, query_map, opts) do
    query_surface.fetch_runtime_observation(query_map, opts)
  end

  defp dispatch_query_surface(_query_surface, surface, _query_map, _opts) do
    {:error,
     Error.validation(
       :invalid_definition,
       "unsupported citadel query surface #{inspect(surface)}"
     )}
  end

  defp normalize_query_result(
         :boundary_session,
         %BoundarySessionDescriptorV1{} = descriptor,
         _query
       ) do
    {:ok, descriptor}
  end

  defp normalize_query_result(:boundary_session, descriptor, %Query{} = query)
       when is_map(descriptor) do
    descriptor
    |> PayloadMigration.migrate_boundary_session_descriptor!()
    |> BoundarySessionDescriptorV1.new!()
    |> then(&{:ok, &1})
  rescue
    error in ArgumentError ->
      {:error,
       Error.validation(:invalid_request, Exception.message(error), request_name: query.name)}
  end

  defp normalize_query_result(:runtime_observation, %RuntimeObservation{} = observation, _query) do
    {:ok, observation}
  end

  defp normalize_query_result(:runtime_observation, observation, %Query{} = query)
       when is_map(observation) do
    {:ok, RuntimeObservation.new!(observation)}
  rescue
    error in ArgumentError ->
      {:error,
       Error.validation(:invalid_request, Exception.message(error), request_name: query.name)}
  end

  defp normalize_query_result(_surface, {:error, %Error{} = error}, _query), do: {:error, error}

  defp normalize_query_result(_surface, _result, %Query{} = query) do
    {:error,
     Error.configuration(
       :not_configured,
       "citadel query surface returned an invalid result",
       component: :query_surface,
       route: query.route.name
     )}
  end

  defp normalize_accepted_result(
         accepted_attrs,
         %RequestContext{} = request_context,
         %Command{} = command
       ) do
    accepted =
      accepted_attrs
      |> PayloadMigration.migrate_accepted_payload!()
      |> Map.put_new(:request_id, request_context.request_id)
      |> Map.put_new(:session_id, request_context.session_id)
      |> Map.put_new(:trace_id, request_context.trace_id)
      |> Accepted.new!()

    {:ok, accepted}
  rescue
    error in ArgumentError ->
      {:error,
       Error.validation(:invalid_request, Exception.message(error), request_name: command.name)}
  end

  defp downstream_error(component, message, reason, trace_id, route) do
    Error.configuration(
      :not_configured,
      message,
      component: component,
      reason: normalize_downstream_reason(reason),
      trace_id: trace_id,
      route: route
    )
  end

  defp normalize_downstream_reason(reason) when is_atom(reason), do: reason
  defp normalize_downstream_reason(reason), do: inspect(reason)

  defp normalize_admin_result(
         result,
         operation,
         %RequestContext{} = request_context,
         %Admin{} = admin
       )
       when is_integer(result) and result >= 0 do
    {:ok,
     %{
       operation: operation,
       affected_count: result,
       request_id: request_context.request_id,
       trace_id: request_context.trace_id,
       admin_name: admin.name,
       auditable?: admin.definition.auditable?
     }}
  end

  defp normalize_admin_result(
         %{} = result,
         operation,
         %RequestContext{} = request_context,
         %Admin{} = admin
       ) do
    {:ok,
     result
     |> Map.put_new(:operation, operation)
     |> Map.put_new(:request_id, request_context.request_id)
     |> Map.put_new(:trace_id, request_context.trace_id)
     |> Map.put_new(:admin_name, admin.name)
     |> Map.put_new(:auditable?, admin.definition.auditable?)}
  end

  defp normalize_admin_result(_result, _operation, _request_context, %Admin{} = admin) do
    {:error,
     Error.configuration(
       :not_configured,
       "citadel maintenance surface returned an invalid result",
       component: :maintenance_surface,
       route: admin.route.name
     )}
  end

  defp fetch_required_surface(nil, field, request) do
    {:error, Error.not_configured(:citadel_adapter, component: field, request_name: request.name)}
  end

  defp fetch_required_surface(surface, _field, _request), do: {:ok, surface}

  defp fetch_route_mapping(metadata, key, request) when is_map(metadata) do
    case Map.get(metadata, key, Map.get(metadata, Atom.to_string(key))) do
      %{} = mapping ->
        {:ok, mapping}

      nil ->
        {:error,
         Error.validation(
           :invalid_definition,
           "route #{inspect(request.route.name)} is missing #{inspect(key)} metadata",
           route: request.route.name,
           request_name: request.name
         )}

      value ->
        {:error,
         Error.validation(
           :invalid_definition,
           "route #{inspect(request.route.name)} #{inspect(key)} metadata must be a map, got: #{inspect(value)}",
           route: request.route.name,
           request_name: request.name
         )}
    end
  end

  defp fetch_required_mapping_string(mapping, key, request) do
    case Map.get(mapping, key, Map.get(mapping, Atom.to_string(key))) do
      value ->
        if present_string?(value) do
          {:ok, value}
        else
          {:error,
           Error.validation(
             :invalid_definition,
             "route #{inspect(request.route.name)} requires #{inspect(key)} to be a non-empty string, got: #{inspect(value)}",
             route: request.route.name,
             request_name: request.name
           )}
        end
    end
  end

  defp fetch_optional_mapping_string(mapping, key, default) do
    case Map.get(mapping, key, Map.get(mapping, Atom.to_string(key), default)) do
      nil ->
        {:ok, nil}

      value ->
        if present_string?(value) do
          {:ok, value}
        else
          {:error,
           Error.validation(
             :invalid_definition,
             "#{inspect(key)} must be a non-empty string when present",
             actual: inspect(value)
           )}
        end
    end
  end

  defp fetch_mapping_atom(mapping, key, default, request) do
    case Map.get(mapping, key, Map.get(mapping, Atom.to_string(key), default)) do
      nil when is_nil(default) ->
        {:error,
         Error.validation(
           :invalid_definition,
           "route #{inspect(request.route.name)} requires #{inspect(key)} to be an atom",
           route: request.route.name,
           request_name: request.name
         )}

      value when is_atom(value) ->
        {:ok, value}

      value ->
        {:error,
         Error.validation(
           :invalid_definition,
           "#{inspect(key)} must be an atom",
           route: request.route.name,
           request_name: request.name,
           actual: inspect(value)
         )}
    end
  end

  defp fetch_mapping_boolean(mapping, key, default, request) do
    case Map.get(mapping, key, Map.get(mapping, Atom.to_string(key), default)) do
      value when is_boolean(value) ->
        {:ok, value}

      value ->
        {:error,
         Error.validation(:invalid_definition, "#{inspect(key)} must be a boolean",
           route: request.route.name,
           request_name: request.name,
           actual: inspect(value)
         )}
    end
  end

  defp fetch_mapping_list(mapping, key, default) do
    case Map.get(mapping, key, Map.get(mapping, Atom.to_string(key), default)) do
      value when is_list(value) ->
        {:ok,
         Enum.map(value, fn
           item when is_binary(item) and item != "" ->
             item

           item ->
             raise ArgumentError,
                   "#{inspect(key)} entries must be non-empty strings, got: #{inspect(item)}"
         end)}

      value ->
        {:error,
         Error.validation(:invalid_definition, "#{inspect(key)} must be a list",
           actual: inspect(value)
         )}
    end
  rescue
    error in ArgumentError ->
      {:error, Error.validation(:invalid_definition, error.message)}
  end

  defp build_plan_hints(mapping, input, %RequestContext{} = request_context, capability, request) do
    with {:ok, execution_mapping} <- fetch_execution_mapping(mapping, request),
         {:ok, candidate_step} <-
           build_candidate_step(execution_mapping, input, request_context, capability, request) do
      {:ok,
       PlanHints.new!(%{
         candidate_steps: [candidate_step],
         preferred_targets: [],
         preferred_topology: nil,
         budget_hints: nil,
         extensions: %{}
       })}
    end
  rescue
    error in ArgumentError ->
      {:error,
       Error.validation(:invalid_definition, Exception.message(error),
         request_name: request.name,
         route: request.route.name
       )}
  end

  defp fetch_execution_mapping(mapping, request) do
    case Map.get(mapping, :execution, Map.get(mapping, "execution")) do
      %{} = execution_mapping ->
        {:ok, Map.new(execution_mapping)}

      nil ->
        {:error,
         Error.validation(
           :invalid_definition,
           "route #{inspect(request.route.name)} requires :execution metadata for Citadel command submission",
           route: request.route.name,
           request_name: request.name
         )}

      other ->
        {:error,
         Error.validation(
           :invalid_definition,
           "route #{inspect(request.route.name)} execution metadata must be a map",
           route: request.route.name,
           request_name: request.name,
           actual: inspect(other)
         )}
    end
  end

  defp build_candidate_step(execution_mapping, input, request_context, capability, request) do
    with {:ok, step_kind} <-
           fetch_optional_execution_string(execution_mapping, :step_kind, "capability"),
         {:ok, allowed_operations} <-
           fetch_required_execution_list(execution_mapping, :allowed_operations, request),
         {:ok, execution_intent_family} <-
           fetch_optional_execution_string(execution_mapping, :execution_intent_family, "process"),
         {:ok, execution_intent_template} <-
           fetch_required_execution_map(execution_mapping, :execution_intent, request) do
      execution_intent =
        resolve_execution_template(execution_intent_template, input, request_context)

      citadel_extensions =
        %{
          "execution_intent_family" => execution_intent_family,
          "execution_intent" => execution_intent
        }
        |> maybe_put("allowed_tools", optional_execution_list(execution_mapping, :allowed_tools))
        |> maybe_put(
          "effect_classes",
          optional_execution_list(execution_mapping, :effect_classes)
        )
        |> maybe_put(
          "workspace_mutability",
          optional_execution_string(execution_mapping, :workspace_mutability)
        )
        |> maybe_put(
          "placement_intent",
          optional_execution_string(execution_mapping, :placement_intent)
        )
        |> maybe_put(
          "downstream_scope",
          optional_execution_string(execution_mapping, :downstream_scope)
        )
        |> maybe_put(
          "sandbox_level",
          optional_execution_string(execution_mapping, :sandbox_level)
        )
        |> maybe_put(
          "sandbox_approvals",
          optional_execution_string(execution_mapping, :sandbox_approvals)
        )
        |> maybe_put(
          "execution_family",
          optional_execution_string(execution_mapping, :execution_family)
        )
        |> maybe_put(
          "node_affinity",
          optional_execution_string(execution_mapping, :node_affinity)
        )
        |> maybe_put("cpu_class", optional_execution_string(execution_mapping, :cpu_class))
        |> maybe_put("memory_class", optional_execution_string(execution_mapping, :memory_class))
        |> maybe_put(
          "wall_clock_budget_ms",
          optional_execution_non_neg_integer(execution_mapping, :wall_clock_budget_ms)
        )

      {:ok,
       CandidateStep.new!(%{
         step_kind: step_kind,
         capability_id: capability,
         allowed_operations: allowed_operations,
         extensions: %{"citadel" => citadel_extensions}
       })}
    end
  end

  defp fetch_optional_execution_string(execution_mapping, key, default) do
    case optional_execution_string(execution_mapping, key) do
      nil -> {:ok, default}
      value -> {:ok, value}
    end
  end

  defp fetch_required_execution_list(execution_mapping, key, request) do
    case optional_execution_list(execution_mapping, key) do
      nil ->
        {:error,
         Error.validation(
           :invalid_definition,
           "route #{inspect(request.route.name)} execution metadata requires #{inspect(key)}",
           route: request.route.name,
           request_name: request.name
         )}

      [] ->
        {:error,
         Error.validation(
           :invalid_definition,
           "route #{inspect(request.route.name)} execution metadata #{inspect(key)} must not be empty",
           route: request.route.name,
           request_name: request.name
         )}

      values ->
        {:ok, values}
    end
  rescue
    error in ArgumentError ->
      {:error,
       Error.validation(:invalid_definition, Exception.message(error),
         route: request.route.name,
         request_name: request.name
       )}
  end

  defp fetch_required_execution_map(execution_mapping, key, request) do
    case Map.get(execution_mapping, key, Map.get(execution_mapping, Atom.to_string(key))) do
      %{} = value ->
        {:ok, Map.new(value)}

      nil ->
        {:error,
         Error.validation(
           :invalid_definition,
           "route #{inspect(request.route.name)} execution metadata requires #{inspect(key)}",
           route: request.route.name,
           request_name: request.name
         )}

      other ->
        {:error,
         Error.validation(
           :invalid_definition,
           "route #{inspect(request.route.name)} execution metadata #{inspect(key)} must be a map",
           route: request.route.name,
           request_name: request.name,
           actual: inspect(other)
         )}
    end
  end

  defp optional_execution_string(execution_mapping, key) do
    case Map.get(execution_mapping, key, Map.get(execution_mapping, Atom.to_string(key))) do
      nil ->
        nil

      value when is_binary(value) ->
        value = String.trim(value)

        if value == "" do
          raise ArgumentError, "execution #{inspect(key)} must be a non-empty string"
        else
          value
        end

      other ->
        raise ArgumentError, "execution #{inspect(key)} must be a string, got: #{inspect(other)}"
    end
  end

  defp optional_execution_list(execution_mapping, key) do
    case Map.get(execution_mapping, key, Map.get(execution_mapping, Atom.to_string(key))) do
      nil ->
        nil

      values when is_list(values) ->
        Enum.map(values, fn
          value when is_binary(value) and value != "" ->
            value

          other ->
            raise ArgumentError,
                  "execution #{inspect(key)} entries must be non-empty strings, got: #{inspect(other)}"
        end)

      other ->
        raise ArgumentError, "execution #{inspect(key)} must be a list, got: #{inspect(other)}"
    end
  end

  defp optional_execution_non_neg_integer(execution_mapping, key) do
    case Map.get(execution_mapping, key, Map.get(execution_mapping, Atom.to_string(key))) do
      nil ->
        nil

      value when is_integer(value) and value >= 0 ->
        value

      other ->
        raise ArgumentError,
              "execution #{inspect(key)} must be a non-negative integer, got: #{inspect(other)}"
    end
  end

  defp resolve_execution_template({:field, field}, input, _request_context) when is_atom(field) do
    payload_value(input, field)
  end

  defp resolve_execution_template({:field, field, default}, input, _request_context)
       when is_atom(field) do
    payload_value(input, field) || default
  end

  defp resolve_execution_template({:context, field}, _input, request_context)
       when is_atom(field) do
    Map.get(request_context, field)
  end

  defp resolve_execution_template({:context, field, default}, _input, request_context)
       when is_atom(field) do
    Map.get(request_context, field) || default
  end

  defp resolve_execution_template(values, input, request_context) when is_list(values) do
    Enum.map(values, &resolve_execution_template(&1, input, request_context))
  end

  defp resolve_execution_template(%{} = value, input, request_context) do
    value
    |> Map.new()
    |> Map.new(fn {key, nested_value} ->
      {key, resolve_execution_template(nested_value, input, request_context)}
    end)
  end

  defp resolve_execution_template(value, _input, _request_context), do: value

  defp fetch_field_value(payload, mapping, field_key, request, default \\ nil) do
    field = Map.get(mapping, field_key, Map.get(mapping, Atom.to_string(field_key)))

    case field do
      nil ->
        missing_field_error(field_key, request, default)

      field ->
        validate_present_field_value(payload_value(payload, field), field, request)
    end
  end

  defp fetch_optional_field_value(payload, mapping, field_key) do
    case Map.get(mapping, field_key, Map.get(mapping, Atom.to_string(field_key))) do
      nil -> {:ok, nil}
      field -> {:ok, payload_value(payload, field)}
    end
  end

  defp fetch_input_keyword(input, mapping, field_key, default_field, request) do
    field =
      Map.get(mapping, field_key, Map.get(mapping, Atom.to_string(field_key), default_field))

    case payload_value(input, field) do
      value when is_list(value) ->
        if Keyword.keyword?(value) do
          {:ok, value}
        else
          {:error,
           Error.validation(
             :invalid_request,
             "#{inspect(field)} must be a keyword list or map",
             request_name: request.name,
             field: field,
             actual: inspect(value)
           )}
        end

      %{} = value ->
        {:ok, Enum.into(value, [])}

      value ->
        {:error,
         Error.validation(
           :invalid_request,
           "#{inspect(field)} must be a keyword list or map",
           request_name: request.name,
           field: field,
           actual: inspect(value)
         )}
    end
  end

  defp fetch_optional_input_keyword(input, mapping, field_key) do
    case Map.get(mapping, field_key, Map.get(mapping, Atom.to_string(field_key))) do
      nil -> {:ok, []}
      field -> normalize_optional_input_keyword(payload_value(input, field), field)
    end
  end

  defp missing_field_error(_field_key, _request, default) when not is_nil(default),
    do: {:ok, default}

  defp missing_field_error(field_key, request, _default) do
    {:error,
     Error.validation(
       :invalid_definition,
       "route #{inspect(request.route.name)} requires #{inspect(field_key)} metadata",
       route: request.route.name,
       request_name: request.name
     )}
  end

  defp validate_present_field_value(value, field, request) do
    if present_string?(value) do
      {:ok, value}
    else
      {:error,
       Error.validation(
         :invalid_request,
         "#{inspect(field)} must be present as a non-empty string",
         request_name: request.name,
         field: field,
         actual: inspect(value)
       )}
    end
  end

  defp normalize_optional_input_keyword(nil, _field), do: {:ok, []}

  defp normalize_optional_input_keyword(value, _field) when is_map(value),
    do: {:ok, Enum.into(value, [])}

  defp normalize_optional_input_keyword(value, field) when is_list(value) do
    if Keyword.keyword?(value) do
      {:ok, value}
    else
      invalid_optional_input_keyword(field, value)
    end
  end

  defp normalize_optional_input_keyword(value, field),
    do: invalid_optional_input_keyword(field, value)

  defp invalid_optional_input_keyword(field, value) do
    {:error,
     Error.validation(
       :invalid_request,
       "#{inspect(field)} must be a keyword list or map",
       field: field,
       actual: inspect(value)
     )}
  end

  defp fetch_required_input_value(input, mapping, field_key, default_field, request) do
    field =
      Map.get(mapping, field_key, Map.get(mapping, Atom.to_string(field_key), default_field))

    case payload_value(input, field) do
      nil ->
        {:error,
         Error.validation(
           :invalid_request,
           "#{inspect(field)} is required",
           request_name: request.name,
           field: field
         )}

      value ->
        {:ok, value}
    end
  end

  defp fetch_admin_operation(input, mapping) do
    operation_field =
      Map.get(mapping, :operation_field, Map.get(mapping, "operation_field", :operation))

    default_operation =
      Map.get(
        mapping,
        :default_operation,
        Map.get(
          mapping,
          "default_operation",
          {:retry_with_override, "citadel_domain_surface_requested_recovery"}
        )
      )

    {:ok, payload_value(input, operation_field) || default_operation}
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp compact_optional(nil), do: []
  defp compact_optional(value), do: [value]

  defp merged_context(defaults, nil), do: defaults
  defp merged_context(defaults, context), do: Map.merge(defaults, Map.new(context))

  defp context_value(context, key) when is_map(context) do
    context
    |> Map.get(key, Map.get(context, Atom.to_string(key)))
    |> case do
      value when is_binary(value) ->
        trimmed = String.trim(value)
        if trimmed != "", do: value, else: nil

      _ ->
        nil
    end
  end

  defp context_integer(context, key, default) when is_map(context) do
    case Map.get(context, key, Map.get(context, Atom.to_string(key), default)) do
      value when is_integer(value) and value >= 0 -> value
      _ -> default
    end
  end

  defp payload_value(payload, field) when is_map(payload) do
    Map.get(payload, field, Map.get(payload, to_payload_key(field)))
  end

  defp payload_value(_payload, _field), do: nil

  defp to_payload_key(field) when is_atom(field), do: Atom.to_string(field)
  defp to_payload_key(field), do: field

  defp optional_query_value(params, mapping, field_key) do
    case Map.get(mapping, field_key, Map.get(mapping, Atom.to_string(field_key))) do
      nil -> nil
      field -> payload_value(params, field)
    end
  end

  defp bounded_metadata_keys(metadata) do
    metadata
    |> Map.keys()
    |> Enum.map(fn
      key when is_atom(key) -> Atom.to_string(key)
      key when is_binary(key) -> key
      key -> inspect(key)
    end)
    |> Enum.sort()
    |> Enum.take(16)
  end

  defp provenance_extensions(request, %RequestContext{} = request_context) do
    %{
      "request_name" => Atom.to_string(request.name),
      "route_name" => Atom.to_string(request.route.name),
      "idempotency_key" => request_context.idempotency_key,
      "trace_origin" => Atom.to_string(request_context.trace_origin),
      "host_request_id" => request_context.host_request_id,
      "metadata_keys" => request_context.metadata_keys
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp require_context_field(value, _field) when is_binary(value) and value != "", do: :ok

  defp require_context_field(_value, field) do
    {:error,
     Error.validation(
       :invalid_context,
       "citadel command submission requires #{field} in command context",
       field: field
     )}
  end

  defp present_string?(value) when is_binary(value), do: String.trim(value) != ""
  defp present_string?(_value), do: false
end
