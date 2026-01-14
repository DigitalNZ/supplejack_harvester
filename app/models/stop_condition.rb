# frozen_string_literal: true

class StopCondition < ApplicationRecord
  belongs_to :extraction_definition

  # rubocop:disable Lint/UnusedBlockArgument
  # rubocop:disable Security/Eval
  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Style/OpenStructUse
  def evaluate(document)
    block = ->(response) { eval(content) }

    context =
      if content.include?('headers')
        OpenStruct.new(
          body: document&.body,
          headers: document&.response_headers,
          status: document&.status
        )
      else
        OpenStruct.new(
          body: document&.body,
          status: document&.status
        )
      end

    block.call(context)
  rescue StandardError => e
    e
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
