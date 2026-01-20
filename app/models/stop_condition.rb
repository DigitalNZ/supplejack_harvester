# frozen_string_literal: true

require 'ostruct'

class StopCondition < ApplicationRecord
  belongs_to :extraction_definition

  # rubocop:disable Lint/UnusedBlockArgument
  # rubocop:disable Security/Eval
  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Style/OpenStructUse
  def evaluate(document_extraction)
    block = ->(response) { eval(content) }

    document = document_extraction.document
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

    block.call(OpenStruct.new({ document: document, body: body, status: status, headers: headers }))
  rescue StandardError => e
    Airbrake.notify(e)
    false
  end

  # rubocop:enable Lint/UnusedBlockArgument
  # rubocop:enable Security/Eval
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Style/OpenStructUse
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
