defmodule Citadel.DomainSurface.Adapters.CitadelAdapter.RequestSubmission do
  @moduledoc false

  alias Citadel.{DecisionRejection, IntentEnvelope}
  alias Citadel.DomainSurface.Adapters.CitadelAdapter.RequestContext

  @type accepted_result :: {:accepted, map()}
  @type rejected_result :: {:rejected, DecisionRejection.t() | map()}
  @type submission_result :: accepted_result() | rejected_result() | {:error, term()}

  @callback submit_envelope(IntentEnvelope.t(), RequestContext.t(), keyword()) ::
              submission_result()
end
