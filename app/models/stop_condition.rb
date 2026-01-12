# frozen_string_literal: true

class StopCondition < ApplicationRecord
  belongs_to :extraction_definition

  # rubocop:disable Lint/UnusedBlockArgument
  # rubocop:disable Security/Eval
  def evaluate(response_object)
    block = ->(response) { eval(content) }

    if content.include?('headers')
      StopCondition.new(
        name:,
        content: block.call(OpenStruct.new(
                              {
                                body: response_object&.body,
                                headers: response_object&.response_headers,
                                status: response_object&.status
                              }
                            ))
      )
    else
      StopCondition.new(
        name:,
        content: block.call(response_object&.body)
      )
    end
  rescue StandardError => e
    e
  end
  # rubocop:enable Lint/UnusedBlockArgument
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
