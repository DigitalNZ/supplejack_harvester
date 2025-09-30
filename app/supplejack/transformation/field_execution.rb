# frozen_string_literal: true

module Transformation
  # Only executes the code from the user
  class FieldExecution
    def initialize(field)
      @field = field
    end

    # rubocop:disable Lint/RescueException
    def execute(extracted_record)
      begin
        @value = execute_field_block(extracted_record)
        validate_field_value
      rescue Exception => e
        handle_field_error(e)
      end

      Transformation::TransformedField.new(@field.id, @field.name, @value, @error)
    end
    # rubocop:enable Lint/RescueException

    private

    # rubocop:disable Security/Eval
    def execute_field_block(extracted_record)
      block = ->(_record) { eval(@field.block) }
      block.call(extracted_record)
    end
    # rubocop:enable Security/Eval

    def validate_field_value
      type_checker = TypeChecker.new(@value)
      raise TypeError, type_checker.error unless type_checker.valid?
    end

    def handle_field_error(error)
      harvest_job = find_harvest_job
      log_field_error(error, harvest_job)
      @error = error
    end

    def find_harvest_job
      harvest_definition = @field.transformation_definition.harvest_definitions.first
      return nil if harvest_definition.blank?

      harvest_definition.harvest_jobs.first
    end

    def log_field_error(error, harvest_job)
      JobCompletion::Logger.log_completion(
        error: error,
        definition: @field.transformation_definition,
        job: harvest_job,
        details: build_field_error_details
      )
    end

    def build_field_error_details
      {
        field_name: @field.name,
        field_id: @field.id,
        stop_condition_name: @field.name,
        stop_condition_type: 'field_error'
      }
    end
  end
end
