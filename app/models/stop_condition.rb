# frozen_string_literal: true

class StopCondition < ApplicationRecord
  belongs_to :extraction_definition

  # rubocop:disable Security/Eval
  def evaluate(document_extraction)
    response = document_extraction.document

    Airbrake.notify("Response: #{response}")

    # Locals exposed to eval (THIS is the key)
    body = response.body
    status = response.status
    headers = response.respond_to?(:response_headers) ? response.response_headers : {}

    eval(content)
  rescue StandardError => e
    Airbrake.notify(e)
    false
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
