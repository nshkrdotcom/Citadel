defmodule Citadel.ExecutionPacket.Helpers do
  @moduledoc false

  alias Citadel.ContractCore.Value

  def require_contract_version!(attrs, field, module_name, expected_version) do
    Value.required(attrs, field, module_name, fn value ->
      value = Value.string!(value, "#{module_name}.#{field}")

      if value == expected_version do
        value
      else
        raise ArgumentError,
              "#{module_name}.#{field} must be #{inspect(expected_version)}, got: #{inspect(value)}"
      end
    end)
  end

  def required_string(attrs, field, module_name) do
    Value.required(attrs, field, module_name, fn value ->
      Value.string!(value, "#{module_name}.#{field}")
    end)
  end

  def optional_string(attrs, field, module_name, default \\ nil) do
    Value.optional(
      attrs,
      field,
      module_name,
      fn value ->
        Value.string!(value, "#{module_name}.#{field}")
      end,
      default
    )
  end

  def required_datetime(attrs, field, module_name) do
    Value.required(attrs, field, module_name, fn value ->
      Value.datetime!(value, "#{module_name}.#{field}")
    end)
  end

  def optional_datetime(attrs, field, module_name, default \\ nil) do
    Value.optional(
      attrs,
      field,
      module_name,
      fn value ->
        Value.datetime!(value, "#{module_name}.#{field}")
      end,
      default
    )
  end

  def required_json_object(attrs, field, module_name) do
    Value.required(attrs, field, module_name, fn value ->
      Value.json_object!(value, "#{module_name}.#{field}")
    end)
  end

  def optional_json_object(attrs, field, module_name, default \\ %{}) do
    Value.optional(
      attrs,
      field,
      module_name,
      fn value ->
        Value.json_object!(value, "#{module_name}.#{field}")
      end,
      default
    )
  end

  def required_string_list(attrs, field, module_name) do
    Value.required(attrs, field, module_name, fn value ->
      Value.list!(
        value,
        "#{module_name}.#{field}",
        fn item ->
          Value.string!(item, "#{module_name}.#{field}")
        end,
        allow_empty?: false
      )
    end)
  end

  def optional_string_list(attrs, field, module_name, default \\ []) do
    Value.optional(
      attrs,
      field,
      module_name,
      fn value ->
        Value.list!(value, "#{module_name}.#{field}", fn item ->
          Value.string!(item, "#{module_name}.#{field}")
        end)
      end,
      default
    )
  end

  def optional_struct_list(attrs, field, module_name, target_module, default \\ []) do
    Value.optional(
      attrs,
      field,
      module_name,
      fn value ->
        Value.list!(value, "#{module_name}.#{field}", fn item ->
          Value.module!(item, target_module, "#{module_name}.#{field}")
        end)
      end,
      default
    )
  end

  def required_non_neg_integer(attrs, field, module_name) do
    Value.required(attrs, field, module_name, fn value ->
      Value.non_neg_integer!(value, "#{module_name}.#{field}")
    end)
  end
end

defmodule Citadel.HttpExecutionIntent.V1 do
  @moduledoc """
  Initial provisional HTTP lower intent packet.
  """

  alias Citadel.ContractCore.Value
  alias Citadel.ExecutionPacket.Helpers

  @contract_version "v1"
  @fields [:contract_version, :method, :url, :headers, :body, :extensions]

  @type t :: %__MODULE__{
          contract_version: String.t(),
          method: String.t(),
          url: String.t(),
          headers: map(),
          body: term(),
          extensions: map()
        }

  @enforce_keys [:contract_version, :method, :url, :headers, :extensions]
  defstruct contract_version: @contract_version,
            method: nil,
            url: nil,
            headers: %{},
            body: nil,
            extensions: %{}

  def contract_version, do: @contract_version

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.HttpExecutionIntent.V1", @fields)

    %__MODULE__{
      contract_version:
        Helpers.require_contract_version!(
          attrs,
          :contract_version,
          "Citadel.HttpExecutionIntent.V1",
          @contract_version
        ),
      method: Helpers.required_string(attrs, :method, "Citadel.HttpExecutionIntent.V1"),
      url: Helpers.required_string(attrs, :url, "Citadel.HttpExecutionIntent.V1"),
      headers: Helpers.required_json_object(attrs, :headers, "Citadel.HttpExecutionIntent.V1"),
      body:
        Value.optional(
          attrs,
          :body,
          "Citadel.HttpExecutionIntent.V1",
          fn value ->
            Value.json_value!(value, "Citadel.HttpExecutionIntent.V1.body")
          end,
          nil
        ),
      extensions:
        Helpers.optional_json_object(attrs, :extensions, "Citadel.HttpExecutionIntent.V1")
    }
  end

  def dump(%__MODULE__{} = intent) do
    %{
      contract_version: intent.contract_version,
      method: intent.method,
      url: intent.url,
      headers: intent.headers,
      body: intent.body,
      extensions: intent.extensions
    }
  end
end

defmodule Citadel.ProcessExecutionIntent.V1 do
  @moduledoc """
  Initial provisional process lower intent packet.
  """

  alias Citadel.ContractCore.Value
  alias Citadel.ExecutionPacket.Helpers

  @contract_version "v1"
  @fields [
    :contract_version,
    :command,
    :args,
    :working_directory,
    :environment,
    :stdin,
    :extensions
  ]

  @type t :: %__MODULE__{
          contract_version: String.t(),
          command: String.t(),
          args: [String.t()],
          working_directory: String.t() | nil,
          environment: map(),
          stdin: term(),
          extensions: map()
        }

  @enforce_keys [:contract_version, :command, :args, :environment, :extensions]
  defstruct contract_version: @contract_version,
            command: nil,
            args: [],
            working_directory: nil,
            environment: %{},
            stdin: nil,
            extensions: %{}

  def contract_version, do: @contract_version

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.ProcessExecutionIntent.V1", @fields)

    %__MODULE__{
      contract_version:
        Helpers.require_contract_version!(
          attrs,
          :contract_version,
          "Citadel.ProcessExecutionIntent.V1",
          @contract_version
        ),
      command: Helpers.required_string(attrs, :command, "Citadel.ProcessExecutionIntent.V1"),
      args: Helpers.required_string_list(attrs, :args, "Citadel.ProcessExecutionIntent.V1"),
      working_directory:
        Helpers.optional_string(attrs, :working_directory, "Citadel.ProcessExecutionIntent.V1"),
      environment:
        Helpers.optional_json_object(attrs, :environment, "Citadel.ProcessExecutionIntent.V1"),
      stdin:
        Value.optional(
          attrs,
          :stdin,
          "Citadel.ProcessExecutionIntent.V1",
          fn value ->
            Value.json_value!(value, "Citadel.ProcessExecutionIntent.V1.stdin")
          end,
          nil
        ),
      extensions:
        Helpers.optional_json_object(attrs, :extensions, "Citadel.ProcessExecutionIntent.V1")
    }
  end

  def dump(%__MODULE__{} = intent) do
    %{
      contract_version: intent.contract_version,
      command: intent.command,
      args: intent.args,
      working_directory: intent.working_directory,
      environment: intent.environment,
      stdin: intent.stdin,
      extensions: intent.extensions
    }
  end
end

defmodule Citadel.JsonRpcExecutionIntent.V1 do
  @moduledoc """
  Initial provisional JSON-RPC lower intent packet.
  """

  alias Citadel.ContractCore.Value
  alias Citadel.ExecutionPacket.Helpers

  @contract_version "v1"
  @fields [:contract_version, :endpoint, :method, :params, :extensions]

  @type t :: %__MODULE__{
          contract_version: String.t(),
          endpoint: String.t(),
          method: String.t(),
          params: map(),
          extensions: map()
        }

  @enforce_keys @fields
  defstruct contract_version: @contract_version,
            endpoint: nil,
            method: nil,
            params: %{},
            extensions: %{}

  def contract_version, do: @contract_version

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.JsonRpcExecutionIntent.V1", @fields)

    %__MODULE__{
      contract_version:
        Helpers.require_contract_version!(
          attrs,
          :contract_version,
          "Citadel.JsonRpcExecutionIntent.V1",
          @contract_version
        ),
      endpoint: Helpers.required_string(attrs, :endpoint, "Citadel.JsonRpcExecutionIntent.V1"),
      method: Helpers.required_string(attrs, :method, "Citadel.JsonRpcExecutionIntent.V1"),
      params: Helpers.required_json_object(attrs, :params, "Citadel.JsonRpcExecutionIntent.V1"),
      extensions:
        Helpers.optional_json_object(attrs, :extensions, "Citadel.JsonRpcExecutionIntent.V1")
    }
  end

  def dump(%__MODULE__{} = intent) do
    %{
      contract_version: intent.contract_version,
      endpoint: intent.endpoint,
      method: intent.method,
      params: intent.params,
      extensions: intent.extensions
    }
  end
end

defmodule Citadel.CredentialHandleRef.V1 do
  @moduledoc """
  Lower credential-handle carrier owned below the Citadel invoke seam.
  """

  alias Citadel.ContractCore.Value
  alias Citadel.ExecutionPacket.Helpers

  @contract_version "v1"
  @fields [
    :contract_version,
    :credential_handle_id,
    :handle_kind,
    :handle_ref,
    :expires_at,
    :extensions
  ]

  @type t :: %__MODULE__{
          contract_version: String.t(),
          credential_handle_id: String.t(),
          handle_kind: String.t(),
          handle_ref: String.t(),
          expires_at: DateTime.t() | nil,
          extensions: map()
        }

  @enforce_keys [:contract_version, :credential_handle_id, :handle_kind, :handle_ref, :extensions]
  defstruct contract_version: @contract_version,
            credential_handle_id: nil,
            handle_kind: nil,
            handle_ref: nil,
            expires_at: nil,
            extensions: %{}

  def contract_version, do: @contract_version

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.CredentialHandleRef.V1", @fields)

    %__MODULE__{
      contract_version:
        Helpers.require_contract_version!(
          attrs,
          :contract_version,
          "Citadel.CredentialHandleRef.V1",
          @contract_version
        ),
      credential_handle_id:
        Helpers.required_string(attrs, :credential_handle_id, "Citadel.CredentialHandleRef.V1"),
      handle_kind: Helpers.required_string(attrs, :handle_kind, "Citadel.CredentialHandleRef.V1"),
      handle_ref: Helpers.required_string(attrs, :handle_ref, "Citadel.CredentialHandleRef.V1"),
      expires_at: Helpers.optional_datetime(attrs, :expires_at, "Citadel.CredentialHandleRef.V1"),
      extensions:
        Helpers.optional_json_object(attrs, :extensions, "Citadel.CredentialHandleRef.V1")
    }
  end

  def dump(%__MODULE__{} = handle_ref) do
    %{
      contract_version: handle_ref.contract_version,
      credential_handle_id: handle_ref.credential_handle_id,
      handle_kind: handle_ref.handle_kind,
      handle_ref: handle_ref.handle_ref,
      expires_at: handle_ref.expires_at,
      extensions: handle_ref.extensions
    }
  end
end

defmodule Citadel.AttachGrant.V1 do
  @moduledoc """
  Durable lower attach-grant fact normalized by `boundary_bridge`.
  """

  alias Citadel.ContractCore.Value
  alias Citadel.CredentialHandleRef.V1, as: CredentialHandleRefV1
  alias Citadel.ExecutionPacket.Helpers

  @contract_version "v1"
  @fields [
    :contract_version,
    :attach_grant_id,
    :boundary_session_id,
    :boundary_ref,
    :session_id,
    :granted_at,
    :expires_at,
    :credential_handle_refs,
    :extensions
  ]

  @type t :: %__MODULE__{
          contract_version: String.t(),
          attach_grant_id: String.t(),
          boundary_session_id: String.t(),
          boundary_ref: String.t(),
          session_id: String.t(),
          granted_at: DateTime.t(),
          expires_at: DateTime.t() | nil,
          credential_handle_refs: [CredentialHandleRefV1.t()],
          extensions: map()
        }

  @enforce_keys [
    :contract_version,
    :attach_grant_id,
    :boundary_session_id,
    :boundary_ref,
    :session_id,
    :granted_at,
    :credential_handle_refs,
    :extensions
  ]
  defstruct contract_version: @contract_version,
            attach_grant_id: nil,
            boundary_session_id: nil,
            boundary_ref: nil,
            session_id: nil,
            granted_at: nil,
            expires_at: nil,
            credential_handle_refs: [],
            extensions: %{}

  def contract_version, do: @contract_version

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.AttachGrant.V1", @fields)

    %__MODULE__{
      contract_version:
        Helpers.require_contract_version!(
          attrs,
          :contract_version,
          "Citadel.AttachGrant.V1",
          @contract_version
        ),
      attach_grant_id: Helpers.required_string(attrs, :attach_grant_id, "Citadel.AttachGrant.V1"),
      boundary_session_id:
        Helpers.required_string(attrs, :boundary_session_id, "Citadel.AttachGrant.V1"),
      boundary_ref: Helpers.required_string(attrs, :boundary_ref, "Citadel.AttachGrant.V1"),
      session_id: Helpers.required_string(attrs, :session_id, "Citadel.AttachGrant.V1"),
      granted_at: Helpers.required_datetime(attrs, :granted_at, "Citadel.AttachGrant.V1"),
      expires_at: Helpers.optional_datetime(attrs, :expires_at, "Citadel.AttachGrant.V1"),
      credential_handle_refs:
        Helpers.optional_struct_list(
          attrs,
          :credential_handle_refs,
          "Citadel.AttachGrant.V1",
          CredentialHandleRefV1
        ),
      extensions: Helpers.optional_json_object(attrs, :extensions, "Citadel.AttachGrant.V1")
    }
  end

  def dump(%__MODULE__{} = grant) do
    %{
      contract_version: grant.contract_version,
      attach_grant_id: grant.attach_grant_id,
      boundary_session_id: grant.boundary_session_id,
      boundary_ref: grant.boundary_ref,
      session_id: grant.session_id,
      granted_at: grant.granted_at,
      expires_at: grant.expires_at,
      credential_handle_refs:
        Enum.map(grant.credential_handle_refs, &CredentialHandleRefV1.dump/1),
      extensions: grant.extensions
    }
  end
end

defmodule Citadel.ExecutionRoute.V1 do
  @moduledoc """
  Durable lower execution route fact.
  """

  alias Citadel.ContractCore.Value
  alias Citadel.ExecutionPacket.Helpers

  @contract_version "v1"
  @transport_families ["http", "process", "json_rpc"]
  @fields [
    :contract_version,
    :route_id,
    :intent_envelope_id,
    :downstream_scope,
    :transport_family,
    :target_locator,
    :boundary_session_id,
    :extensions
  ]

  @type t :: %__MODULE__{
          contract_version: String.t(),
          route_id: String.t(),
          intent_envelope_id: String.t(),
          downstream_scope: String.t(),
          transport_family: String.t(),
          target_locator: map(),
          boundary_session_id: String.t() | nil,
          extensions: map()
        }

  @enforce_keys [
    :contract_version,
    :route_id,
    :intent_envelope_id,
    :downstream_scope,
    :transport_family,
    :target_locator,
    :extensions
  ]
  defstruct contract_version: @contract_version,
            route_id: nil,
            intent_envelope_id: nil,
            downstream_scope: nil,
            transport_family: nil,
            target_locator: %{},
            boundary_session_id: nil,
            extensions: %{}

  def contract_version, do: @contract_version
  def transport_families, do: @transport_families

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.ExecutionRoute.V1", @fields)

    route = %__MODULE__{
      contract_version:
        Helpers.require_contract_version!(
          attrs,
          :contract_version,
          "Citadel.ExecutionRoute.V1",
          @contract_version
        ),
      route_id: Helpers.required_string(attrs, :route_id, "Citadel.ExecutionRoute.V1"),
      intent_envelope_id:
        Helpers.required_string(attrs, :intent_envelope_id, "Citadel.ExecutionRoute.V1"),
      downstream_scope:
        Helpers.required_string(attrs, :downstream_scope, "Citadel.ExecutionRoute.V1"),
      transport_family:
        Helpers.required_string(attrs, :transport_family, "Citadel.ExecutionRoute.V1"),
      target_locator:
        Helpers.required_json_object(attrs, :target_locator, "Citadel.ExecutionRoute.V1"),
      boundary_session_id:
        Helpers.optional_string(attrs, :boundary_session_id, "Citadel.ExecutionRoute.V1"),
      extensions: Helpers.optional_json_object(attrs, :extensions, "Citadel.ExecutionRoute.V1")
    }

    if route.transport_family in @transport_families do
      route
    else
      raise ArgumentError,
            "Citadel.ExecutionRoute.V1.transport_family must be one of #{inspect(@transport_families)}"
    end
  end

  def dump(%__MODULE__{} = route) do
    %{
      contract_version: route.contract_version,
      route_id: route.route_id,
      intent_envelope_id: route.intent_envelope_id,
      downstream_scope: route.downstream_scope,
      transport_family: route.transport_family,
      target_locator: route.target_locator,
      boundary_session_id: route.boundary_session_id,
      extensions: route.extensions
    }
  end
end

defmodule Citadel.BoundarySessionDescriptor.V1 do
  @moduledoc """
  Durable lower boundary-session fact normalized by `boundary_bridge` and `query_bridge`.
  """

  alias Citadel.ContractCore.Value
  alias Citadel.ExecutionPacket.Helpers

  @contract_version "v1"
  @allowed_statuses ["attaching", "attached", "stale", "expired", "detached", "failed"]
  @fields [
    :contract_version,
    :boundary_session_id,
    :boundary_ref,
    :session_id,
    :tenant_id,
    :target_id,
    :boundary_class,
    :status,
    :attach_mode,
    :lease_expires_at,
    :last_heartbeat_at,
    :extensions
  ]

  @type t :: %__MODULE__{
          contract_version: String.t(),
          boundary_session_id: String.t(),
          boundary_ref: String.t(),
          session_id: String.t(),
          tenant_id: String.t(),
          target_id: String.t(),
          boundary_class: String.t(),
          status: String.t(),
          attach_mode: String.t(),
          lease_expires_at: DateTime.t() | nil,
          last_heartbeat_at: DateTime.t() | nil,
          extensions: map()
        }

  @enforce_keys [
    :contract_version,
    :boundary_session_id,
    :boundary_ref,
    :session_id,
    :tenant_id,
    :target_id,
    :boundary_class,
    :status,
    :attach_mode,
    :extensions
  ]
  defstruct contract_version: @contract_version,
            boundary_session_id: nil,
            boundary_ref: nil,
            session_id: nil,
            tenant_id: nil,
            target_id: nil,
            boundary_class: nil,
            status: nil,
            attach_mode: nil,
            lease_expires_at: nil,
            last_heartbeat_at: nil,
            extensions: %{}

  def contract_version, do: @contract_version
  def allowed_statuses, do: @allowed_statuses

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.BoundarySessionDescriptor.V1", @fields)

    descriptor = %__MODULE__{
      contract_version:
        Helpers.require_contract_version!(
          attrs,
          :contract_version,
          "Citadel.BoundarySessionDescriptor.V1",
          @contract_version
        ),
      boundary_session_id:
        Helpers.required_string(
          attrs,
          :boundary_session_id,
          "Citadel.BoundarySessionDescriptor.V1"
        ),
      boundary_ref:
        Helpers.required_string(attrs, :boundary_ref, "Citadel.BoundarySessionDescriptor.V1"),
      session_id:
        Helpers.required_string(attrs, :session_id, "Citadel.BoundarySessionDescriptor.V1"),
      tenant_id:
        Helpers.required_string(attrs, :tenant_id, "Citadel.BoundarySessionDescriptor.V1"),
      target_id:
        Helpers.required_string(attrs, :target_id, "Citadel.BoundarySessionDescriptor.V1"),
      boundary_class:
        Helpers.required_string(attrs, :boundary_class, "Citadel.BoundarySessionDescriptor.V1"),
      status: Helpers.required_string(attrs, :status, "Citadel.BoundarySessionDescriptor.V1"),
      attach_mode:
        Helpers.required_string(attrs, :attach_mode, "Citadel.BoundarySessionDescriptor.V1"),
      lease_expires_at:
        Helpers.optional_datetime(
          attrs,
          :lease_expires_at,
          "Citadel.BoundarySessionDescriptor.V1"
        ),
      last_heartbeat_at:
        Helpers.optional_datetime(
          attrs,
          :last_heartbeat_at,
          "Citadel.BoundarySessionDescriptor.V1"
        ),
      extensions:
        Helpers.optional_json_object(attrs, :extensions, "Citadel.BoundarySessionDescriptor.V1")
    }

    if descriptor.status in @allowed_statuses do
      descriptor
    else
      raise ArgumentError,
            "Citadel.BoundarySessionDescriptor.V1.status must be one of #{inspect(@allowed_statuses)}"
    end
  end

  def dump(%__MODULE__{} = descriptor) do
    %{
      contract_version: descriptor.contract_version,
      boundary_session_id: descriptor.boundary_session_id,
      boundary_ref: descriptor.boundary_ref,
      session_id: descriptor.session_id,
      tenant_id: descriptor.tenant_id,
      target_id: descriptor.target_id,
      boundary_class: descriptor.boundary_class,
      status: descriptor.status,
      attach_mode: descriptor.attach_mode,
      lease_expires_at: descriptor.lease_expires_at,
      last_heartbeat_at: descriptor.last_heartbeat_at,
      extensions: descriptor.extensions
    }
  end
end

defmodule Citadel.ExecutionEvent.V1 do
  @moduledoc """
  Raw lower execution fact consumed as an event.
  """

  alias Citadel.ContractCore.Value
  alias Citadel.ExecutionPacket.Helpers

  @contract_version "v1"
  @fields [
    :contract_version,
    :execution_event_id,
    :intent_envelope_id,
    :entry_id,
    :causal_group_id,
    :route_id,
    :session_id,
    :trace_id,
    :boundary_ref,
    :event_kind,
    :status,
    :occurred_at,
    :payload,
    :extensions
  ]

  @type t :: %__MODULE__{
          contract_version: String.t(),
          execution_event_id: String.t(),
          intent_envelope_id: String.t(),
          entry_id: String.t(),
          causal_group_id: String.t(),
          route_id: String.t(),
          session_id: String.t(),
          trace_id: String.t(),
          boundary_ref: String.t() | nil,
          event_kind: String.t(),
          status: String.t(),
          occurred_at: DateTime.t(),
          payload: map(),
          extensions: map()
        }

  @enforce_keys [
    :contract_version,
    :execution_event_id,
    :intent_envelope_id,
    :entry_id,
    :causal_group_id,
    :route_id,
    :session_id,
    :trace_id,
    :event_kind,
    :status,
    :occurred_at,
    :payload,
    :extensions
  ]
  defstruct contract_version: @contract_version,
            execution_event_id: nil,
            intent_envelope_id: nil,
            entry_id: nil,
            causal_group_id: nil,
            route_id: nil,
            session_id: nil,
            trace_id: nil,
            boundary_ref: nil,
            event_kind: nil,
            status: nil,
            occurred_at: nil,
            payload: %{},
            extensions: %{}

  def contract_version, do: @contract_version

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.ExecutionEvent.V1", @fields)

    %__MODULE__{
      contract_version:
        Helpers.require_contract_version!(
          attrs,
          :contract_version,
          "Citadel.ExecutionEvent.V1",
          @contract_version
        ),
      execution_event_id:
        Helpers.required_string(attrs, :execution_event_id, "Citadel.ExecutionEvent.V1"),
      intent_envelope_id:
        Helpers.required_string(attrs, :intent_envelope_id, "Citadel.ExecutionEvent.V1"),
      entry_id: Helpers.required_string(attrs, :entry_id, "Citadel.ExecutionEvent.V1"),
      causal_group_id:
        Helpers.required_string(attrs, :causal_group_id, "Citadel.ExecutionEvent.V1"),
      route_id: Helpers.required_string(attrs, :route_id, "Citadel.ExecutionEvent.V1"),
      session_id: Helpers.required_string(attrs, :session_id, "Citadel.ExecutionEvent.V1"),
      trace_id: Helpers.required_string(attrs, :trace_id, "Citadel.ExecutionEvent.V1"),
      boundary_ref: Helpers.optional_string(attrs, :boundary_ref, "Citadel.ExecutionEvent.V1"),
      event_kind: Helpers.required_string(attrs, :event_kind, "Citadel.ExecutionEvent.V1"),
      status: Helpers.required_string(attrs, :status, "Citadel.ExecutionEvent.V1"),
      occurred_at: Helpers.required_datetime(attrs, :occurred_at, "Citadel.ExecutionEvent.V1"),
      payload: Helpers.required_json_object(attrs, :payload, "Citadel.ExecutionEvent.V1"),
      extensions: Helpers.optional_json_object(attrs, :extensions, "Citadel.ExecutionEvent.V1")
    }
  end

  def dump(%__MODULE__{} = event) do
    %{
      contract_version: event.contract_version,
      execution_event_id: event.execution_event_id,
      intent_envelope_id: event.intent_envelope_id,
      entry_id: event.entry_id,
      causal_group_id: event.causal_group_id,
      route_id: event.route_id,
      session_id: event.session_id,
      trace_id: event.trace_id,
      boundary_ref: event.boundary_ref,
      event_kind: event.event_kind,
      status: event.status,
      occurred_at: event.occurred_at,
      payload: event.payload,
      extensions: event.extensions
    }
  end
end

defmodule Citadel.ExecutionOutcome.V1 do
  @moduledoc """
  Raw lower execution terminal fact consumed as an outcome.
  """

  alias Citadel.ContractCore.Value
  alias Citadel.ExecutionPacket.Helpers

  @contract_version "v1"
  @fields [
    :contract_version,
    :execution_outcome_id,
    :intent_envelope_id,
    :entry_id,
    :causal_group_id,
    :route_id,
    :session_id,
    :trace_id,
    :boundary_ref,
    :status,
    :result,
    :finished_at,
    :extensions
  ]

  @type t :: %__MODULE__{
          contract_version: String.t(),
          execution_outcome_id: String.t(),
          intent_envelope_id: String.t(),
          entry_id: String.t(),
          causal_group_id: String.t(),
          route_id: String.t(),
          session_id: String.t(),
          trace_id: String.t(),
          boundary_ref: String.t() | nil,
          status: String.t(),
          result: map(),
          finished_at: DateTime.t(),
          extensions: map()
        }

  @enforce_keys [
    :contract_version,
    :execution_outcome_id,
    :intent_envelope_id,
    :entry_id,
    :causal_group_id,
    :route_id,
    :session_id,
    :trace_id,
    :status,
    :result,
    :finished_at,
    :extensions
  ]
  defstruct contract_version: @contract_version,
            execution_outcome_id: nil,
            intent_envelope_id: nil,
            entry_id: nil,
            causal_group_id: nil,
            route_id: nil,
            session_id: nil,
            trace_id: nil,
            boundary_ref: nil,
            status: nil,
            result: %{},
            finished_at: nil,
            extensions: %{}

  def contract_version, do: @contract_version

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.ExecutionOutcome.V1", @fields)

    %__MODULE__{
      contract_version:
        Helpers.require_contract_version!(
          attrs,
          :contract_version,
          "Citadel.ExecutionOutcome.V1",
          @contract_version
        ),
      execution_outcome_id:
        Helpers.required_string(attrs, :execution_outcome_id, "Citadel.ExecutionOutcome.V1"),
      intent_envelope_id:
        Helpers.required_string(attrs, :intent_envelope_id, "Citadel.ExecutionOutcome.V1"),
      entry_id: Helpers.required_string(attrs, :entry_id, "Citadel.ExecutionOutcome.V1"),
      causal_group_id:
        Helpers.required_string(attrs, :causal_group_id, "Citadel.ExecutionOutcome.V1"),
      route_id: Helpers.required_string(attrs, :route_id, "Citadel.ExecutionOutcome.V1"),
      session_id: Helpers.required_string(attrs, :session_id, "Citadel.ExecutionOutcome.V1"),
      trace_id: Helpers.required_string(attrs, :trace_id, "Citadel.ExecutionOutcome.V1"),
      boundary_ref: Helpers.optional_string(attrs, :boundary_ref, "Citadel.ExecutionOutcome.V1"),
      status: Helpers.required_string(attrs, :status, "Citadel.ExecutionOutcome.V1"),
      result: Helpers.required_json_object(attrs, :result, "Citadel.ExecutionOutcome.V1"),
      finished_at: Helpers.required_datetime(attrs, :finished_at, "Citadel.ExecutionOutcome.V1"),
      extensions: Helpers.optional_json_object(attrs, :extensions, "Citadel.ExecutionOutcome.V1")
    }
  end

  def dump(%__MODULE__{} = outcome) do
    %{
      contract_version: outcome.contract_version,
      execution_outcome_id: outcome.execution_outcome_id,
      intent_envelope_id: outcome.intent_envelope_id,
      entry_id: outcome.entry_id,
      causal_group_id: outcome.causal_group_id,
      route_id: outcome.route_id,
      session_id: outcome.session_id,
      trace_id: outcome.trace_id,
      boundary_ref: outcome.boundary_ref,
      status: outcome.status,
      result: outcome.result,
      finished_at: outcome.finished_at,
      extensions: outcome.extensions
    }
  end
end

defmodule Citadel.ExecutionIntentEnvelope.V1 do
  @moduledoc """
  Explicit Wave 5 handoff from `Citadel.InvocationRequest` into the lower execution packet family.
  """

  alias Citadel.AuthorityContract.AuthorityDecision.V1, as: AuthorityDecisionV1
  alias Citadel.BoundaryIntent
  alias Citadel.ContractCore.Value
  alias Citadel.ExecutionPacket.Helpers
  alias Citadel.HttpExecutionIntent.V1, as: HttpExecutionIntentV1
  alias Citadel.JsonRpcExecutionIntent.V1, as: JsonRpcExecutionIntentV1
  alias Citadel.ProcessExecutionIntent.V1, as: ProcessExecutionIntentV1
  alias Citadel.TopologyIntent

  @contract_version "v1"
  @intent_families %{
    "http" => HttpExecutionIntentV1,
    "process" => ProcessExecutionIntentV1,
    "json_rpc" => JsonRpcExecutionIntentV1
  }
  @fields [
    :contract_version,
    :intent_envelope_id,
    :entry_id,
    :causal_group_id,
    :invocation_request_id,
    :invocation_schema_version,
    :request_id,
    :session_id,
    :tenant_id,
    :trace_id,
    :actor_id,
    :target_id,
    :target_kind,
    :allowed_operations,
    :authority_packet,
    :boundary_intent,
    :topology_intent,
    :execution_intent_family,
    :execution_intent,
    :extensions
  ]

  @type execution_intent_t ::
          HttpExecutionIntentV1.t() | ProcessExecutionIntentV1.t() | JsonRpcExecutionIntentV1.t()

  @type t :: %__MODULE__{
          contract_version: String.t(),
          intent_envelope_id: String.t(),
          entry_id: String.t(),
          causal_group_id: String.t(),
          invocation_request_id: String.t(),
          invocation_schema_version: pos_integer(),
          request_id: String.t(),
          session_id: String.t(),
          tenant_id: String.t(),
          trace_id: String.t(),
          actor_id: String.t(),
          target_id: String.t(),
          target_kind: String.t(),
          allowed_operations: [String.t()],
          authority_packet: AuthorityDecisionV1.t(),
          boundary_intent: BoundaryIntent.t(),
          topology_intent: TopologyIntent.t(),
          execution_intent_family: String.t(),
          execution_intent: execution_intent_t(),
          extensions: map()
        }

  @enforce_keys @fields
  defstruct @fields

  def contract_version, do: @contract_version
  def intent_families, do: Map.keys(@intent_families)

  def new!(attrs) do
    attrs = Value.normalize_attrs!(attrs, "Citadel.ExecutionIntentEnvelope.V1", @fields)

    execution_intent_family =
      Helpers.required_string(
        attrs,
        :execution_intent_family,
        "Citadel.ExecutionIntentEnvelope.V1"
      )

    execution_module =
      case Map.fetch(@intent_families, execution_intent_family) do
        {:ok, module} ->
          module

        :error ->
          raise ArgumentError,
                "Citadel.ExecutionIntentEnvelope.V1.execution_intent_family must be one of #{inspect(Map.keys(@intent_families))}"
      end

    %__MODULE__{
      contract_version:
        Helpers.require_contract_version!(
          attrs,
          :contract_version,
          "Citadel.ExecutionIntentEnvelope.V1",
          @contract_version
        ),
      intent_envelope_id:
        Helpers.required_string(attrs, :intent_envelope_id, "Citadel.ExecutionIntentEnvelope.V1"),
      entry_id: Helpers.required_string(attrs, :entry_id, "Citadel.ExecutionIntentEnvelope.V1"),
      causal_group_id:
        Helpers.required_string(attrs, :causal_group_id, "Citadel.ExecutionIntentEnvelope.V1"),
      invocation_request_id:
        Helpers.required_string(
          attrs,
          :invocation_request_id,
          "Citadel.ExecutionIntentEnvelope.V1"
        ),
      invocation_schema_version:
        Helpers.required_non_neg_integer(
          attrs,
          :invocation_schema_version,
          "Citadel.ExecutionIntentEnvelope.V1"
        ),
      request_id:
        Helpers.required_string(attrs, :request_id, "Citadel.ExecutionIntentEnvelope.V1"),
      session_id:
        Helpers.required_string(attrs, :session_id, "Citadel.ExecutionIntentEnvelope.V1"),
      tenant_id: Helpers.required_string(attrs, :tenant_id, "Citadel.ExecutionIntentEnvelope.V1"),
      trace_id: Helpers.required_string(attrs, :trace_id, "Citadel.ExecutionIntentEnvelope.V1"),
      actor_id: Helpers.required_string(attrs, :actor_id, "Citadel.ExecutionIntentEnvelope.V1"),
      target_id: Helpers.required_string(attrs, :target_id, "Citadel.ExecutionIntentEnvelope.V1"),
      target_kind:
        Helpers.required_string(attrs, :target_kind, "Citadel.ExecutionIntentEnvelope.V1"),
      allowed_operations:
        Helpers.required_string_list(
          attrs,
          :allowed_operations,
          "Citadel.ExecutionIntentEnvelope.V1"
        ),
      authority_packet:
        Value.required(attrs, :authority_packet, "Citadel.ExecutionIntentEnvelope.V1", fn value ->
          Value.module!(
            value,
            AuthorityDecisionV1,
            "Citadel.ExecutionIntentEnvelope.V1.authority_packet"
          )
        end),
      boundary_intent:
        Value.required(attrs, :boundary_intent, "Citadel.ExecutionIntentEnvelope.V1", fn value ->
          Value.module!(
            value,
            BoundaryIntent,
            "Citadel.ExecutionIntentEnvelope.V1.boundary_intent"
          )
        end),
      topology_intent:
        Value.required(attrs, :topology_intent, "Citadel.ExecutionIntentEnvelope.V1", fn value ->
          Value.module!(
            value,
            TopologyIntent,
            "Citadel.ExecutionIntentEnvelope.V1.topology_intent"
          )
        end),
      execution_intent_family: execution_intent_family,
      execution_intent:
        Value.required(attrs, :execution_intent, "Citadel.ExecutionIntentEnvelope.V1", fn value ->
          Value.module!(
            value,
            execution_module,
            "Citadel.ExecutionIntentEnvelope.V1.execution_intent"
          )
        end),
      extensions:
        Helpers.optional_json_object(attrs, :extensions, "Citadel.ExecutionIntentEnvelope.V1")
    }
  end

  def dump(%__MODULE__{} = envelope) do
    %{
      contract_version: envelope.contract_version,
      intent_envelope_id: envelope.intent_envelope_id,
      entry_id: envelope.entry_id,
      causal_group_id: envelope.causal_group_id,
      invocation_request_id: envelope.invocation_request_id,
      invocation_schema_version: envelope.invocation_schema_version,
      request_id: envelope.request_id,
      session_id: envelope.session_id,
      tenant_id: envelope.tenant_id,
      trace_id: envelope.trace_id,
      actor_id: envelope.actor_id,
      target_id: envelope.target_id,
      target_kind: envelope.target_kind,
      allowed_operations: envelope.allowed_operations,
      authority_packet: AuthorityDecisionV1.dump(envelope.authority_packet),
      boundary_intent: BoundaryIntent.dump(envelope.boundary_intent),
      topology_intent: TopologyIntent.dump(envelope.topology_intent),
      execution_intent_family: envelope.execution_intent_family,
      execution_intent: dump_execution_intent(envelope.execution_intent),
      extensions: envelope.extensions
    }
  end

  defp dump_execution_intent(%HttpExecutionIntentV1{} = intent),
    do: HttpExecutionIntentV1.dump(intent)

  defp dump_execution_intent(%ProcessExecutionIntentV1{} = intent),
    do: ProcessExecutionIntentV1.dump(intent)

  defp dump_execution_intent(%JsonRpcExecutionIntentV1{} = intent),
    do: JsonRpcExecutionIntentV1.dump(intent)
end
