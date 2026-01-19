# frozen_string_literal: true

require 'ostruct'

class StopCondition < ApplicationRecord
  belongs_to :extraction_definition

  # rubocop:disable Lint/UnusedBlockArgument
  # rubocop:disable Security/Eval
  # rubocop:disable Metrics/MethodLength
  def evaluate(document)
    block = ->(response) { eval(content) }

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
