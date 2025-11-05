# frozen_string_literal: true

module JobCompletion
  class Logger
    @accumulated_errors = {}
    @mutex = Mutex.new

    class << self
      attr_accessor :accumulated_errors, :mutex
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
        job_errors = accumulated_errors[job.id] || {}
        
        if job_errors[error_signature]
          job_errors[error_signature][:count] += 1
        else
          job_errors[error_signature] = {
            type: :field_error,
            count: 1,
            error: error,
            definition: definition,
            job: job,
            details: details
          }
        end
        
        accumulated_errors[job.id] = job_errors
      end
    end

    # Store stop condition in memory (accumulates by stop condition signature)
    def self.store_stop_condition(condition, definition, job, details)
      return unless job

      # Build stop condition signature to identify duplicates
      stop_condition_signature = build_stop_condition_signature(condition, details)

      mutex.synchronize do
        job_errors = accumulated_errors[job.id] || {}
        
        if job_errors[stop_condition_signature]
          job_errors[stop_condition_signature][:count] += 1
        else
          job_errors[stop_condition_signature] = {
            type: :stop_condition,
            count: 1,
            condition: condition,
            definition: definition,
            job: job,
            details: details
          }
        end
        
        accumulated_errors[job.id] = job_errors
      end
    end

    # This is called once the transformation is finished
    # It will log all the accumulated field errors to the database
    def self.update_summary_with_field_errors(harvest_job_id)
      field_errors_to_process = nil

      mutex.synchronize do
        errors_hash = accumulated_errors[harvest_job_id]
        return unless errors_hash

        # Filter and process only field errors, then remove them from the hash
        field_errors_to_process = errors_hash.select { |_signature, error_data| error_data[:type] == :field_error }
        return if field_errors_to_process.empty?

        # Remove processed entries from the hash
        field_errors_to_process.each_key { |signature| errors_hash.delete(signature) }
        
        # Clean up empty hash
        accumulated_errors.delete(harvest_job_id) if errors_hash.empty?
      end

      # Process outside the mutex to avoid holding the lock during I/O
      field_errors_to_process.each do |_signature, error_data|
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

    # This is called once the extraction is finished
    # It will log all the accumulated stop conditions to the database
    def self.update_summary_with_stop_conditions(extraction_job_id)
      stop_conditions_to_process = nil

      mutex.synchronize do
        errors_hash = accumulated_errors[extraction_job_id]
        return unless errors_hash

        # Filter and process only stop conditions, then remove them from the hash
        stop_conditions_to_process = errors_hash.select { |_signature, error_data| error_data[:type] == :stop_condition }
        return if stop_conditions_to_process.empty?

        # Remove processed entries from the hash
        stop_conditions_to_process.each_key { |signature| errors_hash.delete(signature) }
        
        # Clean up empty hash
        accumulated_errors.delete(extraction_job_id) if errors_hash.empty?
      end

      # Process outside the mutex to avoid holding the lock during I/O
      stop_conditions_to_process.each do |_signature, error_data|
        log_completion(
          origin: 'Extraction::Execution',
          error: error_data[:condition],
          definition: error_data[:definition],
          job: error_data[:job],
          details: error_data[:details],
          count: error_data[:count]
        )
      end
    rescue StandardError => e
      Rails.logger.error "Failed to update summary with stop conditions: #{e.message}"
    end

    private

    def self.build_error_signature(error, field_id)
      stack_trace = error.backtrace&.first(5)&.join('|') || 'no_stack'
      "#{error.class.name}|#{stack_trace}|#{field_id}"
    end

    def self.build_stop_condition_signature(condition, details)
      stop_condition_name = details[:stop_condition_name] || 'unknown'
      stop_condition_type = details[:stop_condition_type] || 'unknown'
      "#{stop_condition_type}|#{stop_condition_name}"
    end
  end
end