# frozen_string_literal: true

module Transformation
  # Only executes the code from the user
  class FieldExecution
    def initialize(field)
      @field = field
    end

    # rubocop:disable Security/Eval
    # rubocop:disable Lint/RescueException
    def execute(extracted_record)
      begin
        block = ->(_record) { eval(@field.block) }

        @value = block.call(extracted_record)
        type_checker = TypeChecker.new(@value)
        raise TypeError, type_checker.error unless type_checker.valid?
      rescue Exception => e
        Airbrake.notify "Error Tranforming field: #{@field.name} #{e}"
        @error = e
      end

      Transformation::TransformedField.new(@field.id, @field.name, @value, @error)
    end
    # rubocop:enable Lint/RescueException
    # rubocop:enable Security/Eval
  end
end
