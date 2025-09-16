# frozen_string_literal: true

module Transformation
  # Only executes the code from the user
  class FieldExecution
    def initialize(field)
      @field = field
    end

    # rubocop:disable Lint/UnusedBlockArgument
    # rubocop:disable Security/Eval
    # rubocop:disable Lint/RescueException
    def execute(extracted_record)
      begin
        block = ->(record) { eval(@field.block) }

        @value = block.call(extracted_record)
        type_checker = TypeChecker.new(@value)
        raise TypeError, type_checker.error unless type_checker.valid?
      rescue Exception => e
        @error = e
      end

      Transformation::TransformedField.new(@field.id, @field.name, @value, @error)
    end
    # rubocop:enable Lint/UnusedBlockArgument
    # rubocop:enable Security/Eval
    # rubocop:enable Lint/RescueException
  end
end
