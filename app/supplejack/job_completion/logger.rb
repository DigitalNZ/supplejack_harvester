# frozen_string_literal: true

module JobCompletion
  class Logger
    @accumulated_field_errors = {}
    @mutex = Mutex.new

    class << self
      attr_accessor :accumulated_field_errors, :mutex
    end

    def self.log_completion(args)
      context = ContextBuilder.build_context_from_args(args)
      CompletionSummaryBuilder.build_completion_summary(context)
    rescue StandardError => e
      Rails.logger.error "Failed to log completion: #{e.message}"
    end

    # Store field error in memory (accumulates by error signature)
    def self.store_field_error(error, definition, job, details)
      return unless job

      # Build error signature to identify duplicates
      error_signature = build_error_signature(error, details[:field_id])

      mutex.synchronize do
        harvest_job_errors = accumulated_field_errors[job.id] || {}
        
        if harvest_job_errors[error_signature]
          harvest_job_errors[error_signature][:count] += 1
        else
          harvest_job_errors[error_signature] = {
            count: 1,
            error: error,
            definition: definition,
            job: job,
            details: details
          }
        end
        
        accumulated_field_errors[job.id] = harvest_job_errors
      end
    end

    # This is called once the transformation is finished
    # It will log all the accumulated field errors to the database
    def self.update_summary_with_field_errors(harvest_job_id)
      errors_hash = accumulated_field_errors.delete(harvest_job_id)
      return unless errors_hash

      errors_hash.each do |error_signature, error_data|
        log_completion(
          origin: 'Transformation::FieldExecution',
          error: error_data[:error],
          definition: error_data[:definition],
          job: error_data[:job],
          details: error_data[:details],
          count: error_data[:count]
        )
      end
    rescue StandardError => e
      Rails.logger.error "Failed to update summary with field errors: #{e.message}"
    end

    private

    def self.build_error_signature(error, field_id)
      stack_trace = error.backtrace&.first(5)&.join('|') || 'no_stack'
      "#{error.class.name}|#{stack_trace}|#{field_id}"
    end
  end
end