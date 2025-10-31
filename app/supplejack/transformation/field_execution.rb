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
        handle_field_error(error)
      end

      Transformation::TransformedField.new(@field.id, @field.name, @value, @error)
    end
    # rubocop:enable Lint/UnusedBlockArgument
    # rubocop:enable Security/Eval

    private

    def handle_field_error(error)
      harvest_job = find_harvest_job
      log_field_error(error, harvest_job)
    end

    def log_field_error(error, harvest_job)

      # To prevent hammering the DB, we want to log once every 30 seconds
      @last_log_time ||= {}
      cache_key = "#{@field.transformation_definition.id}_#{@field.id}"
      last_log = @last_log_time[cache_key]
      
      return if last_log && (Time.current - last_log) < 30.seconds

      JobCompletion::Logger.log_completion(
        origin: 'Transformation::FieldExecution',
        error: error,
        definition: @field.transformation_definition,
        job: harvest_job,
        details: build_field_error_details
      )

      @last_log_time[cache_key] = Time.current
    end

    def build_field_error_details
      {
        field_name: @field.name,
        field_id: @field.id
      }
    end

    def find_harvest_job
      harvest_definition = @field.transformation_definition.harvest_definitions.first
      return nil if harvest_definition.blank?

      harvest_definition.harvest_jobs.first
    end
  end
end
