# frozen_string_literal: true

class StopCondition < ApplicationRecord
  belongs_to :extraction_definition

  # rubocop:disable Lint/UnusedBlockArgument
  # rubocop:disable Security/Eval
  def evaluate(document, execution_context = nil)
    block = ->(response) { eval(content) }

    result = block.call(document)

    execution_context.log_stop_condition_hit(name, content) if result == true && execution_context

    result
  rescue StandardError => error
    error
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
