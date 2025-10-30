# frozen_string_literal: true

module Transformation
  # Only executes the code from the user
  class FieldExecution
    def initialize(field)
      @field = field
    end

    # rubocop:disable Lint/UnusedBlockArgument
    # rubocop:disable Security/Eval
    def execute(extracted_record)
      begin
        block = ->(record) { eval(@field.block) }

        @value = block.call(extracted_record)
        type_checker = TypeChecker.new(@value)
        raise TypeError, type_checker.error unless type_checker.valid?
      rescue Exception => e
        Rails.logger.error "Transformation::FieldExecution: #{e.message}"
      end

      Transformation::TransformedField.new(@field.id, @field.name, @value, @error)
    end
    # rubocop:enable Lint/UnusedBlockArgument
    # rubocop:enable Security/Eval

    private

    def handle_field_error(error)
      harvest_job = find_harvest_job
      @error = error
    end

    def find_harvest_job
      harvest_definition = @field.transformation_definition.harvest_definitions.first
      return nil if harvest_definition.blank?

      harvest_definition.harvest_jobs.first
    end

    def log_field_error(error, harvest_job)
      JobCompletion::Logger.log_completion(
        origin: 'Transformation::FieldExecution',
        error: error,
        definition: @field.transformation_definition,
        job: harvest_job,
        details: build_field_error_details
      )
    end

    def build_field_error_details
      {
        field_name: @field.name,
        field_id: @field.id
      }
    end
  end
end
