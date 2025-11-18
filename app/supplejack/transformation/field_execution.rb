# frozen_string_literal: true

module Transformation
  # Only executes the code from the user
  class FieldExecution
    def initialize(field)
      @field = field
    end

    def execute(extracted_record)
      begin
        @value = evaluate_field_block(extracted_record)
        validate_field_value
      rescue Exception => e
        handle_field_execution_error(e)
      end

      Transformation::TransformedField.new(@field.id, @field.name, @value, @error)
    end

    private

    # rubocop:disable Security/Eval
    # rubocop:disable Lint/UnusedBlockArgument
    def evaluate_field_block(extracted_record)
      # :brakeman:ignore Evaluation
      block = ->(record) { eval(@field.block) }
      block.call(extracted_record)
    end
    # rubocop:enable Security/Eval
    # rubocop:enable Lint/UnusedBlockArgument

    def validate_field_value
      type_checker = TypeChecker.new(@value)
      raise TypeError, type_checker.error unless type_checker.valid?
    end

    def handle_field_execution_error(error)
      harvest_definition = @field.transformation_definition.harvest_definitions.first
      harvest_job = harvest_definition&.harvest_jobs&.first
      log_field_error(error, harvest_job)
      @error = error
    end

    def handle_field_error(error)
      harvest_job = find_harvest_job
      log_field_error(error, harvest_job)
      @error = error
    end

    def log_field_error(error, harvest_job)
      return unless harvest_job

      JobCompletionServices::ContextBuilder.create_job_completion_or_error({
                                                                             origin:
                                                                               'Transformation::FieldExecution',
                                                                             error: error,
                                                                             definition:
                                                                               @field.transformation_definition,
                                                                             job: harvest_job
                                                                           })
    end

    def find_harvest_job
      harvest_definition = @field.transformation_definition.harvest_definitions.first
      return nil if harvest_definition.blank?

      harvest_definition.harvest_jobs.first
    end
  end
end
