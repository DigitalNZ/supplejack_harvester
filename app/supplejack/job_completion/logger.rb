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

    # Unified method to store errors and stop conditions in memory (accumulates by signature)
    def self.store_completion(error, definition, job, details)
      return unless job

      # Determine if it's a stop condition or error based on details
      is_stop_condition = details[:stop_condition_name].present?
      
      # Build signature based on type
      signature = if is_stop_condition
        build_stop_condition_signature(error, details)
      else
        build_error_signature(error, details[:field_id])
      end

      mutex.synchronize do
        job_errors = accumulated_errors[job.id] || {}
        
        if job_errors[signature]
          job_errors[signature][:count] += 1
        else
          job_errors[signature] = {
            type: is_stop_condition ? :stop_condition : :field_error,
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

    # Backward compatibility aliases
    def self.store_field_error(error, definition, job, details)
      store_completion(error, definition, job, details)
    end

    def self.store_stop_condition(condition, definition, job, details)
      store_completion(condition, definition, job, details)
    end

    # Unified method to flush all accumulated errors and stop conditions for a job
    # This is called once the transformation or extraction is finished
    def self.update_summary_with_accumulated_errors(job_id)
      errors_to_process = nil

      mutex.synchronize do
        errors_hash = accumulated_errors[job_id]
        return unless errors_hash

        errors_to_process = errors_hash.dup
        accumulated_errors.delete(job_id)
      end

      # Process outside the mutex to avoid holding the lock during I/O
      errors_to_process.each do |_signature, error_data|
        origin = error_data[:type] == :stop_condition ? 'Extraction::Execution' : 'Transformation::FieldExecution'
        error_param = error_data[:error]
        
        log_completion(
          origin: origin,
          error: error_param,
          definition: error_data[:definition],
          job: error_data[:job],
          details: error_data[:details],
          count: error_data[:count]
        )
      end
    rescue StandardError => e
      Rails.logger.error "Failed to update summary with accumulated errors: #{e.message}"
    end

    # Backward compatibility methods
    def self.update_summary_with_field_errors(harvest_job_id)
      errors_to_process = nil

      mutex.synchronize do
        errors_hash = accumulated_errors[harvest_job_id]
        return unless errors_hash

        # Filter and process only field errors, then remove them from the hash
        errors_to_process = errors_hash.select { |_signature, error_data| error_data[:type] == :field_error }
        return if errors_to_process.empty?

        # Remove processed entries from the hash
        errors_to_process.each_key { |signature| errors_hash.delete(signature) }
        
        # Clean up empty hash
        accumulated_errors.delete(harvest_job_id) if errors_hash.empty?
      end

      # Process outside the mutex to avoid holding the lock during I/O
      errors_to_process.each do |_signature, error_data|
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

    def self.update_summary_with_stop_conditions(extraction_job_id)
      errors_to_process = nil

      mutex.synchronize do
        errors_hash = accumulated_errors[extraction_job_id]
        return unless errors_hash

        # Filter and process only stop conditions, then remove them from the hash
        errors_to_process = errors_hash.select { |_signature, error_data| error_data[:type] == :stop_condition }
        return if errors_to_process.empty?

        # Remove processed entries from the hash
        errors_to_process.each_key { |signature| errors_hash.delete(signature) }
        
        # Clean up empty hash
        accumulated_errors.delete(extraction_job_id) if errors_hash.empty?
      end

      # Process outside the mutex to avoid holding the lock during I/O
      errors_to_process.each do |_signature, error_data|
        log_completion(
          origin: 'Extraction::Execution',
          error: error_data[:error],
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