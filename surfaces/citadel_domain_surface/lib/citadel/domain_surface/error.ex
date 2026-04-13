defmodule Citadel.DomainSurface.Error do
  @moduledoc """
  Frozen host-facing error vocabulary for the Domain boundary.

  Domain never returns raw Citadel `DecisionRejection` structs as its public
  contract. Instead it translates them into a stable Domain error with:

  - a frozen Domain `code`
  - Domain `category`
  - preserved Citadel `retryability`
  - preserved Citadel `publication_requirement`
  - bounded source detail for operators

  The rejection translation matrix is intentionally small and stage-shaped:

  - `:ingress_normalization -> :request_rejected`
  - `:scope_resolution -> :scope_rejected`
  - `:service_admission -> :service_rejected`
  - `:planning -> :planning_rejected`
  - `:authority_compilation -> :policy_rejected`
  - `:projection -> :projection_rejected`
  """

  alias Citadel.DecisionRejection

  @type category :: :configuration | :validation | :unsupported | :rejected
  @type code ::
          :not_configured
          | :missing_idempotency_key
          | :invalid_context
          | :invalid_definition
          | :invalid_metadata
          | :invalid_request
          | :invalid_trace_id
          | :route_not_found
          | :unsupported_stateful_orchestration
          | :request_rejected
          | :scope_rejected
          | :service_rejected
          | :planning_rejected
          | :policy_rejected
          | :projection_rejected

  @type retryability ::
          :terminal | :after_input_change | :after_runtime_change | :after_governance_change | nil
  @type publication :: :host_only | :review_projection | :derived_state_attachment | nil
  @type vocabulary_map :: %{required(category()) => [code()]}
  @type translation_entry :: %{required(:code) => code(), required(:message) => String.t()}
  @type translation_matrix :: %{required(atom()) => translation_entry()}
  @type source_details :: %{required(:system) => atom(), optional(atom()) => term()}
  @type detail_map :: %{optional(atom()) => term()}
  @type detail_input :: keyword() | detail_map()
  @type rejection_attrs :: %{optional(atom() | String.t()) => term()}
  @type orchestration_value :: term()

  @enforce_keys [:category, :code, :message]
  defstruct [
    :category,
    :code,
    :message,
    :trace_id,
    :retryability,
    :publication,
    :source,
    details: %{}
  ]

  @type t :: %__MODULE__{
          category: category(),
          code: code(),
          message: String.t(),
          trace_id: Citadel.DomainSurface.trace_id() | nil,
          retryability: retryability(),
          publication: publication(),
          source: source_details() | nil,
          details: detail_map()
        }

  @vocabulary %{
    configuration: [:not_configured],
    validation: [
      :missing_idempotency_key,
      :invalid_context,
      :invalid_definition,
      :invalid_metadata,
      :invalid_request,
      :invalid_trace_id,
      :route_not_found
    ],
    unsupported: [:unsupported_stateful_orchestration],
    rejected: [
      :request_rejected,
      :scope_rejected,
      :service_rejected,
      :planning_rejected,
      :policy_rejected,
      :projection_rejected
    ]
  }

  @rejection_translation_matrix %{
    ingress_normalization: %{
      code: :request_rejected,
      message: "request rejected during ingress normalization"
    },
    scope_resolution: %{
      code: :scope_rejected,
      message: "request rejected during scope resolution"
    },
    service_admission: %{
      code: :service_rejected,
      message: "request rejected during service admission"
    },
    planning: %{
      code: :planning_rejected,
      message: "request rejected during planning"
    },
    authority_compilation: %{
      code: :policy_rejected,
      message: "request rejected during policy compilation"
    },
    projection: %{
      code: :projection_rejected,
      message: "request rejected during projection shaping"
    }
  }

  @spec vocabulary() :: vocabulary_map()
  def vocabulary, do: @vocabulary

  @spec rejection_translation_matrix() :: translation_matrix()
  def rejection_translation_matrix, do: @rejection_translation_matrix

  @spec configuration(code(), String.t(), detail_input()) :: t()
  def configuration(code, message, details \\ %{}) do
    build(:configuration, code, message, details)
  end

  @spec validation(code(), String.t(), detail_input()) :: t()
  def validation(code, message, details \\ %{}) do
    build(:validation, code, message, details)
  end

  @spec unsupported(code(), String.t(), detail_input()) :: t()
  def unsupported(code, message, details \\ %{}) do
    build(:unsupported, code, message, details)
  end

  @spec rejected(code(), String.t(), detail_input()) :: t()
  def rejected(code, message, details \\ %{}) do
    build(:rejected, code, message, details)
  end

  @spec not_configured(atom(), keyword()) :: t()
  def not_configured(component, opts \\ []) do
    configuration(
      :not_configured,
      "#{component} is not configured",
      Keyword.put_new(opts, :component, component)
    )
  end

  @spec route_not_found(atom(), keyword()) :: t()
  def route_not_found(request_name, opts \\ []) do
    validation(
      :route_not_found,
      "no route is declared for #{inspect(request_name)}",
      Keyword.put_new(opts, :request_name, request_name)
    )
  end

  @spec missing_idempotency_key(atom(), keyword()) :: t()
  def missing_idempotency_key(request_name, opts \\ []) do
    validation(
      :missing_idempotency_key,
      "commands require idempotency_key at the Domain boundary",
      opts
      |> Keyword.put_new(:request_name, request_name)
      |> Keyword.put_new(:field, :idempotency_key)
    )
  end

  @spec unsupported_stateful_orchestration(orchestration_value(), keyword()) :: t()
  def unsupported_stateful_orchestration(orchestration, opts \\ []) do
    unsupported(
      :unsupported_stateful_orchestration,
      "stateful long-running orchestration requires durable backing; Domain will not hide it in memory",
      Keyword.merge(
        [
          orchestration: inspect(orchestration),
          route: Keyword.get(opts, :route),
          command: Keyword.get(opts, :command)
        ],
        opts
      )
    )
  end

  @spec from_rejection(DecisionRejection.t() | rejection_attrs(), keyword()) :: t()
  def from_rejection(rejection, opts \\ [])

  def from_rejection(%DecisionRejection{} = rejection, opts) do
    translation =
      Map.get(
        @rejection_translation_matrix,
        rejection.stage,
        @rejection_translation_matrix.ingress_normalization
      )

    %__MODULE__{
      category: :rejected,
      code: translation.code,
      message: rejection.summary,
      trace_id: Keyword.get(opts, :trace_id),
      retryability: rejection.retryability,
      publication: rejection.publication_requirement,
      source: %{
        system: :citadel,
        rejection_id: rejection.rejection_id,
        stage: rejection.stage,
        reason_code: rejection.reason_code
      },
      details:
        opts
        |> Keyword.drop([:trace_id])
        |> Enum.into(%{})
        |> Map.merge(%{
          summary: rejection.summary,
          reason_code: rejection.reason_code,
          stage: rejection.stage,
          classification_message: translation.message,
          extensions: rejection.extensions
        })
    }
  end

  def from_rejection(rejection, opts) when is_map(rejection) do
    rejection =
      DecisionRejection.new!(%{
        rejection_id: fetch_rejection_field!(rejection, :rejection_id),
        stage: fetch_rejection_field!(rejection, :stage),
        reason_code: fetch_rejection_field!(rejection, :reason_code),
        summary: fetch_rejection_field!(rejection, :summary),
        retryability: fetch_rejection_field!(rejection, :retryability),
        publication_requirement: fetch_rejection_field!(rejection, :publication_requirement),
        extensions: Map.get(rejection, :extensions, Map.get(rejection, "extensions", %{}))
      })

    from_rejection(rejection, opts)
  end

  defp build(category, code, message, details) do
    details = normalize_details(details)

    %__MODULE__{
      category: category,
      code: code,
      message: message,
      trace_id: Map.get(details, :trace_id),
      retryability: Map.get(details, :retryability),
      publication: Map.get(details, :publication),
      source: Map.get(details, :source),
      details: Map.drop(details, [:trace_id, :retryability, :publication, :source])
    }
  end

  defp normalize_details(details) when is_list(details), do: Enum.into(details, %{})
  defp normalize_details(details) when is_map(details), do: details
  defp normalize_details(_details), do: %{}

  defp fetch_rejection_field!(attrs, key) do
    case Map.fetch(attrs, key) do
      {:ok, value} ->
        value

      :error ->
        Map.fetch!(attrs, Atom.to_string(key))
    end
  end
end
