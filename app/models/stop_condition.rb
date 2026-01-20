# frozen_string_literal: true

class StopCondition < ApplicationRecord
  belongs_to :extraction_definition

  # rubocop:disable Security/Eval
  def evaluate(document_extraction)
    Airbrake.notify("Document Extraction: #{document_extraction}")
    # Airbrake.notify("Response: #{document_extraction.document.response}")
    # Airbrake.notify("Status: #{document_extraction.document.status}")

    # Set local variables for eval to use, mimicking the old behavior
    body = document_extraction.document.body
    headers = document_extraction.document.response.response_headers
    status = document_extraction.document.status

    # Evaluate the stop condition content in the context of these locals
    eval(content)
  rescue StandardError => e
    Airbrake.notify(e)
  end
  # rubocop:enable Security/Eval

  def to_h
    {
      id:,
      name:,
      content:,
      created_at:,
      updated_at:
    }
  end
end
