# frozen_string_literal: true

class StopCondition < ApplicationRecord
  belongs_to :extraction_definition

  # rubocop:disable Security/Eval
  def evaluate(document_extraction)
    document = document_extraction.document

    # Expose locals exactly like before, plus status
    body = document.body
    status = document.status

    # Optional headers support (only if present)
    headers =
      if document.respond_to?(:headers)
        document.headers
      elsif document.respond_to?(:response_headers)
        document.response_headers
      else
        {}
      end

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
