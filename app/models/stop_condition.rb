# frozen_string_literal: true

require 'ostruct'

class StopCondition < ApplicationRecord
  belongs_to :extraction_definition

  # rubocop:disable Lint/UnusedBlockArgument
  # rubocop:disable Security/Eval
  # rubocop:disable Metrics/MethodLength
  def evaluate(document)
    Airbrake.notify("Document: #{document}")

    block = ->(response) { eval(content) }

    Airbrake.notify("Body: #{content.body}") if content.include?('body')
    Airbrake.notify("Headers: #{content.headers}") if content.include?('headers')
    Airbrake.notify("Status: #{content.status}") if content.include?('status')

    if content.exclude?('body') && content.exclude?('headers') && content.exclude?('status')
      Airbrake.notify('No body, headers or status found')
    end

    context =
      if content.include?('headers') || content.include?('status')
        OpenStruct.new(
          body: document.body,
          headers: document.response_headers,
          status: document.status
        )
      else
        document
      end

    block.call(context)
  rescue StandardError => e
    e
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
