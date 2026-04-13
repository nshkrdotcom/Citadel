defmodule Citadel.DomainSurface.Examples.ProvingGround do
  @moduledoc """
  Proving-ground example of the public Domain authoring surface.

  The public host API stays semantic:

  - `compile_workspace/2`
  - `workspace_status/2`
  - `record_operator_evidence/2`
  - `inspect_dead_letter/2`
  - `retry_dead_letter/2`
  - `clear_dead_letter/2`
  - `recover_dead_letters/2`

  Unsupported stateful orchestration is demonstrated explicitly through
  `rebuild_read_model/2`, which fails closed until durable backing exists.
  """

  alias __MODULE__.{AdminCommands, Commands, Queries}

  @type workspace_input :: %{required(:workspace_id) => String.t(), optional(atom()) => term()}
  @type evidence_input :: %{required(:evidence_id) => String.t(), optional(atom()) => term()}
  @type dead_letter_entry_input :: %{
          required(:entry_id) => String.t(),
          optional(atom()) => term()
        }
  @type dead_letter_selector_input ::
          %{
            required(:selector) => keyword() | %{optional(atom()) => term()},
            optional(atom()) => term()
          }

  @spec compile_workspace(workspace_input(), keyword()) ::
          {:ok, Citadel.DomainSurface.Command.t()} | {:error, Citadel.DomainSurface.Error.t()}
  def compile_workspace(input, opts \\ []) do
    Citadel.DomainSurface.command(Commands.CompileWorkspace, input, opts)
  end

  @spec workspace_status(workspace_input(), keyword()) ::
          {:ok, Citadel.DomainSurface.Query.t()} | {:error, Citadel.DomainSurface.Error.t()}
  def workspace_status(params, opts \\ []) do
    Citadel.DomainSurface.query(Queries.WorkspaceStatus, params, opts)
  end

  @spec record_operator_evidence(evidence_input(), keyword()) ::
          {:ok, Citadel.DomainSurface.Command.t()} | {:error, Citadel.DomainSurface.Error.t()}
  def record_operator_evidence(input, opts \\ []) do
    Citadel.DomainSurface.command(Commands.RecordOperatorEvidence, input, opts)
  end

  @spec inspect_dead_letter(dead_letter_entry_input(), keyword()) ::
          {:ok, Citadel.DomainSurface.Admin.t()} | {:error, Citadel.DomainSurface.Error.t()}
  def inspect_dead_letter(input, opts \\ []) do
    Citadel.DomainSurface.admin_command(AdminCommands.InspectDeadLetter, input, opts)
  end

  @spec retry_dead_letter(dead_letter_entry_input(), keyword()) ::
          {:ok, Citadel.DomainSurface.Admin.t()} | {:error, Citadel.DomainSurface.Error.t()}
  def retry_dead_letter(input, opts \\ []) do
    Citadel.DomainSurface.admin_command(AdminCommands.RetryDeadLetter, input, opts)
  end

  @spec clear_dead_letter(dead_letter_entry_input(), keyword()) ::
          {:ok, Citadel.DomainSurface.Admin.t()} | {:error, Citadel.DomainSurface.Error.t()}
  def clear_dead_letter(input, opts \\ []) do
    Citadel.DomainSurface.admin_command(AdminCommands.ClearDeadLetter, input, opts)
  end

  @spec recover_dead_letters(dead_letter_selector_input(), keyword()) ::
          {:ok, Citadel.DomainSurface.Admin.t()} | {:error, Citadel.DomainSurface.Error.t()}
  def recover_dead_letters(input, opts \\ []) do
    Citadel.DomainSurface.admin_command(AdminCommands.RecoverDeadLetters, input, opts)
  end

  @spec rebuild_read_model(workspace_input(), keyword()) ::
          {:ok, Citadel.DomainSurface.Command.t()} | {:error, Citadel.DomainSurface.Error.t()}
  def rebuild_read_model(input, opts \\ []) do
    Citadel.DomainSurface.command(Commands.RebuildReadModel, input, opts)
  end

  defmodule Routes do
    @moduledoc false

    alias Citadel.DomainSurface.Route

    defmodule CompileWorkspace do
      @moduledoc false
      @behaviour Route

      def definition do
        Route.definition!(
          name: :compile_workspace,
          request_type: :command,
          operation: :compile_workspace,
          dispatch_via: :kernel_runtime,
          version: "1.0.0",
          description: "Compile and patch a workspace through the kernel runtime",
          orchestration: :stateless_sync,
          semantic_metadata: %{
            category: :workspace,
            intent: "compile and patch a workspace",
            tags: [:workspace, :write, :primary]
          },
          tool_manifest: %{
            summary: "Compile a workspace and apply the resulting patch",
            examples: [%{workspace_id: "workspace/main"}],
            stability: :stable
          },
          operator_hints: %{
            review_bundle: :workspace_patch,
            queue: :primary
          },
          metadata: %{
            citadel_command: %{
              scope_kind: "workspace",
              scope_id_field: :workspace_id,
              target_kind: "workspace",
              target_id_field: :workspace_id,
              capability: "compile.workspace",
              result_kind: "workspace_patch",
              boundary_requirement: :fresh_or_reuse,
              boundary_class: "workspace_session",
              service_id: "svc.compiler",
              risk_code: "writes_workspace",
              risk_severity: :medium,
              review_required: false,
              success_metric: "workspace_patch_applied",
              routing_tags: ["primary"],
              subject_selectors: ["primary"],
              session_mode_preference: :attached,
              coordination_mode_preference: :single_target,
              execution: %{
                step_kind: "capability",
                allowed_operations: ["shell.exec"],
                execution_intent_family: "process",
                execution_intent: %{
                  contract_version: "v1",
                  command: "echo",
                  args: ["compile", {:field, :workspace_id}],
                  working_directory: {:field, :workspace_root, "/workspace/main"},
                  environment: %{},
                  stdin: nil,
                  extensions: %{}
                },
                allowed_tools: ["bash", "git"],
                effect_classes: ["filesystem", "process"],
                workspace_mutability: "read_write",
                placement_intent: "host_local",
                downstream_scope: "process:workspace",
                wall_clock_budget_ms: 60_000
              }
            }
          }
        )
      end
    end

    defmodule WorkspaceStatus do
      @moduledoc false
      @behaviour Route

      def definition do
        Route.definition!(
          name: :workspace_status,
          request_type: :query,
          operation: :workspace_status,
          dispatch_via: :kernel_runtime,
          version: "1.0.0",
          description: "Read current workspace status through the kernel runtime",
          orchestration: :stateless_sync,
          semantic_metadata: %{
            category: :workspace,
            intent: "read current workspace status",
            tags: [:workspace, :read]
          },
          tool_manifest: %{
            summary: "Read the current workspace status",
            examples: [%{workspace_id: "workspace/main"}],
            stability: :stable
          },
          read_descriptor: %{
            projection: :workspace_status,
            identity_fields: [:workspace_id],
            freshness: :nearline
          },
          metadata: %{
            citadel_query: %{
              surface: :boundary_session,
              downstream_scope: "workspace_status",
              target_id_field: :workspace_id
            }
          }
        )
      end
    end

    defmodule RecordOperatorEvidence do
      @moduledoc false
      @behaviour Route

      def definition do
        Route.definition!(
          name: :record_operator_evidence,
          request_type: :command,
          operation: :record_operator_evidence,
          dispatch_via: :external_integration,
          version: "1.0.0",
          description: "Persist operator evidence through the optional lower integration seam",
          orchestration: :stateless_sync,
          semantic_metadata: %{
            category: :operator,
            intent: "record operator evidence",
            tags: [:operator, :write, :integration]
          },
          tool_manifest: %{
            summary: "Persist operator evidence through the optional integration seam",
            examples: [%{evidence_id: "proof-1"}],
            stability: :provisional
          },
          operator_hints: %{
            evidence_required: true,
            review_bundle: :operator_evidence
          },
          metadata: %{
            external_integration: %{
              purpose: "operator_evidence",
              truth_owner: "optional_lower_adapter",
              durable_truth_owned_by_domain: false
            }
          }
        )
      end
    end

    defmodule InspectDeadLetter do
      @moduledoc false
      @behaviour Route

      def definition do
        Route.definition!(
          name: :inspect_dead_letter,
          request_type: :admin,
          operation: :inspect_dead_letter,
          dispatch_via: :kernel_runtime,
          version: "1.0.0",
          description: "Inspect a dead-letter entry through an explicit admin command",
          orchestration: :stateless_sync,
          semantic_metadata: %{
            category: :maintenance,
            intent: "inspect a dead-letter entry",
            tags: [:operator, :admin, :read]
          },
          tool_manifest: %{
            summary: "Inspect one dead-letter entry",
            examples: [%{entry_id: "entry-1"}],
            stability: :stable
          },
          read_descriptor: %{
            projection: :dead_letter_entry,
            identity_fields: [:entry_id],
            freshness: :transactional
          },
          operator_hints: %{
            review_bundle: :dead_letter_entry
          },
          metadata: %{
            citadel_admin: %{
              entry_id_field: :entry_id
            }
          }
        )
      end
    end

    defmodule RetryDeadLetter do
      @moduledoc false
      @behaviour Route

      def definition do
        Route.definition!(
          name: :retry_dead_letter,
          request_type: :admin,
          operation: :retry_dead_letter,
          dispatch_via: :kernel_runtime,
          description: "Retry a dead-letter entry through an explicit admin command",
          orchestration: :stateless_sync,
          metadata: %{
            citadel_admin: %{
              entry_id_field: :entry_id,
              override_reason_field: :override_reason,
              retry_opts_field: :retry_opts
            }
          }
        )
      end
    end

    defmodule ClearDeadLetter do
      @moduledoc false
      @behaviour Route

      def definition do
        Route.definition!(
          name: :clear_dead_letter,
          request_type: :admin,
          operation: :clear_dead_letter,
          dispatch_via: :kernel_runtime,
          description: "Clear a dead-letter entry through an explicit admin command",
          orchestration: :stateless_sync,
          metadata: %{
            citadel_admin: %{
              entry_id_field: :entry_id,
              override_reason_field: :override_reason
            }
          }
        )
      end
    end

    defmodule RecoverDeadLetters do
      @moduledoc false
      @behaviour Route

      def definition do
        Route.definition!(
          name: :recover_dead_letters,
          request_type: :admin,
          operation: :recover_dead_letters,
          dispatch_via: :kernel_runtime,
          description: "Recover dead-lettered work through an explicit admin command",
          orchestration: :stateless_sync,
          metadata: %{
            citadel_admin: %{
              selector_field: :selector,
              operation_field: :operation,
              default_operation:
                {:retry_with_override, "citadel_domain_surface_requested_recovery"}
            }
          }
        )
      end
    end

    defmodule RebuildReadModel do
      @moduledoc false
      @behaviour Route

      def definition do
        Route.definition!(
          name: :rebuild_read_model,
          request_type: :command,
          operation: :rebuild_read_model,
          dispatch_via: :kernel_runtime,
          description: "Illustrates a stateful long-running flow that requires durable backing",
          orchestration: [mode: :stateful_long_running]
        )
      end
    end
  end

  defmodule LifecycleHooks do
    @moduledoc false

    alias Citadel.DomainSurface.Lifecycle

    defmodule AuditRequest do
      @moduledoc false
      @behaviour Lifecycle

      def definition do
        Lifecycle.definition!(
          name: :audit_request,
          description: "No-op proving-ground lifecycle hook",
          stages: [:before_validation, :before_dispatch, :after_dispatch, :after_error]
        )
      end

      def before_validation(request, context), do: {:ok, request, context}
      def before_dispatch(request, context), do: {:ok, request, context}
      def after_dispatch(_request, result, _context), do: {:ok, result}
      def after_error(_request, _error, _context), do: :ok
    end
  end

  defmodule Policies do
    @moduledoc false

    alias Citadel.DomainSurface.Policy

    defmodule WorkspacePresence do
      @moduledoc false
      @behaviour Policy

      alias Citadel.DomainSurface.Error

      def definition do
        Policy.definition!(
          name: :workspace_presence,
          description: "Require workspace_id for workspace-facing requests",
          mode: :enforced
        )
      end

      def evaluate(%{input: %{} = input}, _context) do
        require_workspace_id(input)
      end

      def evaluate(%{params: %{} = params}, _context) do
        require_workspace_id(params)
      end

      def evaluate(_request, _context) do
        {:error,
         Error.validation(
           :invalid_request,
           "workspace-facing requests must use map input",
           policy: :workspace_presence
         )}
      end

      defp require_workspace_id(%{workspace_id: value}) when is_binary(value) and value != "",
        do: :ok

      defp require_workspace_id(_input) do
        {:error,
         Error.validation(
           :invalid_request,
           "workspace_id is required",
           policy: :workspace_presence,
           field: :workspace_id
         )}
      end
    end
  end

  defmodule Artifacts do
    @moduledoc false

    alias Citadel.DomainSurface.Artifact

    defmodule WorkspacePatch do
      @moduledoc false
      @behaviour Artifact

      def definition do
        Artifact.definition!(
          name: :workspace_patch,
          kind: :projection,
          description: "Host-facing patch artifact for compile workspace"
        )
      end
    end

    defmodule WorkspaceStatus do
      @moduledoc false
      @behaviour Artifact

      def definition do
        Artifact.definition!(
          name: :workspace_status,
          kind: :projection,
          description: "Host-facing status artifact for workspace queries"
        )
      end
    end
  end

  defmodule Commands do
    @moduledoc false

    alias Citadel.DomainSurface.Command

    alias Citadel.DomainSurface.Examples.ProvingGround.{
      Artifacts,
      LifecycleHooks,
      Policies,
      Routes
    }

    defmodule CompileWorkspace do
      @moduledoc false
      @behaviour Command

      def definition do
        Command.definition!(
          name: :compile_workspace,
          route: Routes.CompileWorkspace,
          description: "Compile a workspace and return a host-facing patch artifact",
          lifecycle: [LifecycleHooks.AuditRequest],
          policies: [Policies.WorkspacePresence],
          artifacts: [Artifacts.WorkspacePatch]
        )
      end
    end

    defmodule RecordOperatorEvidence do
      @moduledoc false
      @behaviour Command

      def definition do
        Command.definition!(
          name: :record_operator_evidence,
          route: Routes.RecordOperatorEvidence,
          description: "Persist operator evidence through the optional lower adapter",
          lifecycle: [LifecycleHooks.AuditRequest]
        )
      end
    end

    defmodule RebuildReadModel do
      @moduledoc false
      @behaviour Command

      def definition do
        Command.definition!(
          name: :rebuild_read_model,
          route: Routes.RebuildReadModel,
          description: "Example of an explicitly unsupported stateful flow",
          lifecycle: [LifecycleHooks.AuditRequest],
          policies: [Policies.WorkspacePresence]
        )
      end
    end
  end

  defmodule Queries do
    @moduledoc false

    alias Citadel.DomainSurface.Examples.ProvingGround.{
      Artifacts,
      LifecycleHooks,
      Policies,
      Routes
    }

    alias Citadel.DomainSurface.Query

    defmodule WorkspaceStatus do
      @moduledoc false
      @behaviour Query

      def definition do
        Query.definition!(
          name: :workspace_status,
          route: Routes.WorkspaceStatus,
          description: "Fetch current workspace status",
          lifecycle: [LifecycleHooks.AuditRequest],
          policies: [Policies.WorkspacePresence],
          artifacts: [Artifacts.WorkspaceStatus]
        )
      end
    end
  end

  defmodule AdminCommands do
    @moduledoc false

    alias Citadel.DomainSurface.Admin
    alias Citadel.DomainSurface.Examples.ProvingGround.{LifecycleHooks, Routes}

    defmodule InspectDeadLetter do
      @moduledoc false
      @behaviour Admin

      def definition do
        Admin.definition!(
          name: :inspect_dead_letter,
          route: Routes.InspectDeadLetter,
          description: "Inspect a single dead-letter entry through the explicit admin surface",
          lifecycle: [LifecycleHooks.AuditRequest]
        )
      end
    end

    defmodule RetryDeadLetter do
      @moduledoc false
      @behaviour Admin

      def definition do
        Admin.definition!(
          name: :retry_dead_letter,
          route: Routes.RetryDeadLetter,
          description: "Retry a dead-letter entry through the explicit admin surface",
          lifecycle: [LifecycleHooks.AuditRequest]
        )
      end
    end

    defmodule ClearDeadLetter do
      @moduledoc false
      @behaviour Admin

      def definition do
        Admin.definition!(
          name: :clear_dead_letter,
          route: Routes.ClearDeadLetter,
          description: "Clear a dead-letter entry through the explicit admin surface",
          lifecycle: [LifecycleHooks.AuditRequest]
        )
      end
    end

    defmodule RecoverDeadLetters do
      @moduledoc false
      @behaviour Admin

      def definition do
        Admin.definition!(
          name: :recover_dead_letters,
          route: Routes.RecoverDeadLetters,
          description: "Explicit admin maintenance command for dead-letter recovery",
          lifecycle: [LifecycleHooks.AuditRequest]
        )
      end
    end
  end
end

alias __MODULE__.{AdminCommands, Commands, Queries}
