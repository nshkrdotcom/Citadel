defmodule Citadel.DomainSurface.Examples.ArticlePublishing do
  @moduledoc """
  Thin product-facing example of the public Domain boundary.

  Host code calls semantic helpers:

  - `publish_article/2`
  - `publication_status/2`

  The example also exposes `publish_article_command/2` and
  `publication_status_query/2` for hosts that want to compose explicitly at the
  Domain request-envelope layer.
  """

  alias Citadel.DomainSurface.{Command, Error, Policy, Query}
  alias __MODULE__.{Commands, Queries}

  @type article_input :: %{required(:article_id) => String.t(), optional(atom()) => term()}

  @spec publish_article_command(article_input(), keyword()) ::
          {:ok, Citadel.DomainSurface.Command.t()} | {:error, Error.t()}
  def publish_article_command(input, opts \\ []) do
    Citadel.DomainSurface.command(Commands.PublishArticle, input, opts)
  end

  @spec publish_article(article_input(), keyword()) :: Citadel.DomainSurface.dispatch_result()
  def publish_article(input, opts \\ []) do
    Citadel.DomainSurface.submit(Commands.PublishArticle, input, opts)
  end

  @spec publication_status_query(article_input(), keyword()) ::
          {:ok, Citadel.DomainSurface.Query.t()} | {:error, Error.t()}
  def publication_status_query(params, opts \\ []) do
    Citadel.DomainSurface.query(Queries.PublicationStatus, params, opts)
  end

  @spec publication_status(article_input(), keyword()) :: Citadel.DomainSurface.dispatch_result()
  def publication_status(params, opts \\ []) do
    Citadel.DomainSurface.ask(Queries.PublicationStatus, params, opts)
  end

  defmodule Routes do
    @moduledoc false

    alias Citadel.DomainSurface.Route

    defmodule PublishArticle do
      @moduledoc false
      @behaviour Route

      def definition do
        Route.definition!(
          name: :publish_article,
          request_type: :command,
          operation: :publish_article,
          dispatch_via: :kernel_runtime,
          version: "1.0.0",
          description: "Queue an article publication through the kernel runtime",
          orchestration: :stateless_sync,
          semantic_metadata: %{
            category: :publication,
            intent: "publish an article",
            tags: [:publication, :write]
          },
          tool_manifest: %{
            summary: "Queue publication for one article",
            examples: [%{article_id: "article-42"}],
            stability: :stable
          },
          metadata: %{
            citadel_command: %{
              scope_kind: "publication",
              scope_id_field: :article_id,
              target_kind: "article",
              target_id_field: :article_id,
              capability: "publish.article",
              result_kind: "publication_receipt",
              boundary_requirement: :fresh_or_reuse,
              boundary_class: "publication_session",
              service_id: "svc.publisher",
              risk_code: "publishes_content",
              risk_severity: :medium,
              review_required: false,
              success_metric: "publication_queued",
              routing_tags: ["editorial"],
              subject_selectors: ["editorial"],
              session_mode_preference: :attached,
              coordination_mode_preference: :single_target,
              execution: %{
                step_kind: "capability",
                allowed_operations: ["shell.exec"],
                execution_intent_family: "process",
                execution_intent: %{
                  contract_version: "v1",
                  command: "echo",
                  args: ["publish", {:field, :article_id}],
                  working_directory: "/workspace/publications",
                  environment: %{},
                  stdin: nil,
                  extensions: %{}
                },
                allowed_tools: ["bash", "curl"],
                effect_classes: ["filesystem", "network", "process"],
                workspace_mutability: "ephemeral",
                placement_intent: "host_local",
                downstream_scope: "process:publication",
                wall_clock_budget_ms: 60_000
              }
            }
          }
        )
      end
    end

    defmodule PublicationStatus do
      @moduledoc false
      @behaviour Route

      def definition do
        Route.definition!(
          name: :publication_status,
          request_type: :query,
          operation: :publication_status,
          dispatch_via: :kernel_runtime,
          version: "1.0.0",
          description: "Read the current publication status through the kernel runtime",
          orchestration: :stateless_sync,
          semantic_metadata: %{
            category: :publication,
            intent: "read current publication status",
            tags: [:publication, :read]
          },
          tool_manifest: %{
            summary: "Read the current publication status",
            examples: [%{article_id: "article-42"}],
            stability: :stable
          },
          read_descriptor: %{
            projection: :publication_status,
            identity_fields: [:article_id],
            freshness: :nearline
          },
          metadata: %{
            citadel_query: %{
              surface: :boundary_session,
              downstream_scope: "publication_status",
              target_id_field: :article_id
            }
          }
        )
      end
    end
  end

  defmodule Policies do
    @moduledoc false

    alias Citadel.DomainSurface.Policy

    defmodule ArticleIdentity do
      @moduledoc false
      @behaviour Policy

      alias Citadel.DomainSurface.Error

      def definition do
        Policy.definition!(
          name: :article_identity,
          description: "Require article_id for publication-facing requests",
          mode: :enforced
        )
      end

      def evaluate(%{input: %{} = input}, _context), do: require_article_id(input)
      def evaluate(%{params: %{} = params}, _context), do: require_article_id(params)

      def evaluate(_request, _context) do
        {:error,
         Error.validation(
           :invalid_request,
           "publication-facing requests must use map input",
           policy: :article_identity
         )}
      end

      defp require_article_id(%{article_id: value}) when is_binary(value) and value != "", do: :ok

      defp require_article_id(_input) do
        {:error,
         Error.validation(
           :invalid_request,
           "article_id is required",
           policy: :article_identity,
           field: :article_id
         )}
      end
    end
  end

  defmodule Commands do
    @moduledoc false

    alias Citadel.DomainSurface.Command
    alias Citadel.DomainSurface.Examples.ArticlePublishing.{Policies, Routes}

    defmodule PublishArticle do
      @moduledoc false
      @behaviour Command

      def definition do
        Command.definition!(
          name: :publish_article,
          route: Routes.PublishArticle,
          description: "Semantic host command for editorial publication",
          policies: [Policies.ArticleIdentity]
        )
      end
    end
  end

  defmodule Queries do
    @moduledoc false

    alias Citadel.DomainSurface.Examples.ArticlePublishing.{Policies, Routes}
    alias Citadel.DomainSurface.Query

    defmodule PublicationStatus do
      @moduledoc false
      @behaviour Query

      def definition do
        Query.definition!(
          name: :publication_status,
          route: Routes.PublicationStatus,
          description: "Semantic host query for publication status",
          policies: [Policies.ArticleIdentity]
        )
      end
    end
  end
end
