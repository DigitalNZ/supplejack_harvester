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
        harvest_definition = @field.transformation_definition.harvest_definitions.first
        harvest_job = nil
        if harvest_definition.present?
          harvest_job = harvest_definition.harvest_jobs.first
        end

        JobCompletion::Logger.log_completion(
          error: e,
          definition: @field.transformation_definition,
          job: harvest_job,
          details: {
            field_name: @field.name,
            field_id: @field.id,
            stop_condition_name: @field.name,
            stop_condition_type: 'field_error'
          }
        )
        @error = e
      end

      Transformation::TransformedField.new(@field.id, @field.name, @value, @error)
    end
    # rubocop:enable Lint/UnusedBlockArgument
    # rubocop:enable Security/Eval
    # rubocop:enable Lint/RescueException
  end
end
