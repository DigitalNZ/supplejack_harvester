# frozen_string_literal: true

class StopCondition < ApplicationRecord
  belongs_to :extraction_definition

  # rubocop:disable Lint/UnusedBlockArgument
  # rubocop:disable Security/Eval
  # rubocop:disable Metrics/MethodLength
  def evaluate(document_extraction)
    # Preserve historical lambda binding behavior
    block = ->(response) { eval(content) }

    document = document_extraction.document

    # Locals historically visible inside eval
    body = document.body
    status = document.status

    headers =
      if document.respond_to?(:headers)
        document.headers
      elsif document.respond_to?(:response_headers)
        document.response_headers
      else
        {}
      end

    response = body

    !!block.call(response)
  rescue StandardError => e
    Airbrake.notify(e)
    false
  end
  # rubocop:enable Lint/UnusedBlockArgument
  # rubocop:enable Security/Eval
  # rubocop:enable Metrics/MethodLength

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
