# frozen_string_literal: true

require 'json'

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

    # Unified method to store errors and stop conditions (uses Redis if available, falls back to memory)
    def self.store_completion(error, definition, job, details)
      return unless job

      # Try Redis first, fall back to in-memory if unavailable
      if redis_available?
        store_in_redis(error, definition, job, details)
      else
        store_in_memory(error, definition, job, details)
      end
    rescue StandardError => e
      # Fallback to in-memory if Redis fails
      Rails.logger.warn "Redis unavailable, using in-memory storage: #{e.message}" unless Rails.env.test?
      store_in_memory(error, definition, job, details)
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
      errors_to_process = {}

      # Try to get errors from Redis first
      if redis_available?
        begin
          redis_errors = fetch_from_redis(job_id)
          errors_to_process.merge!(redis_errors) if redis_errors
        rescue StandardError => e
          Rails.logger.warn "Failed to fetch from Redis, trying memory: #{e.message}"
        end
      end

      # Also check in-memory storage (in case some were stored there)
      mutex.synchronize do
        memory_errors = accumulated_errors[job_id]
        if memory_errors
          memory_errors.each do |signature, error_data|
            # Merge with Redis data, keeping the higher count
            if errors_to_process[signature]
              errors_to_process[signature][:count] = [errors_to_process[signature][:count], error_data[:count]].max
            else
              errors_to_process[signature] = error_data
            end
          end
          accumulated_errors.delete(job_id)
        end
      end

      return if errors_to_process.empty?

      # Delete from Redis if we used it
      if redis_available?
        begin
          delete_from_redis(job_id)
        rescue StandardError => e
          Rails.logger.warn "Failed to delete from Redis: #{e.message}"
        end
      end

      # Process outside the mutex to avoid holding the lock during I/O
      errors_to_process.each do |_signature, error_data|
        origin = error_data[:type] == :stop_condition ? 'Extraction::Execution' : 'Transformation::FieldExecution'
        error_param = deserialize_error(error_data[:error])
        
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

    def self.redis_available?
      # Skip Redis in test mode when using fake Sidekiq
      return false if Rails.env.test? && defined?(Sidekiq::Testing) && Sidekiq::Testing.fake_enabled?
      
      begin
        Sidekiq.redis { |conn| conn.call('PING') == 'PONG' }
      rescue StandardError
        false
      end
    end

    def self.store_in_redis(error, definition, job, details)
      # Determine if it's a stop condition or error
      is_stop_condition = details[:stop_condition_name].present?
      
      # Build signature based on type
      signature = if is_stop_condition
        build_stop_condition_signature(error, details)
      else
        build_error_signature(error, details[:field_id])
      end

      # Serialize error for storage
      serialized_error = serialize_error(error)
      
      Sidekiq.redis do |conn|
        key = "job_completion:errors:#{job.id}"
        
        # Check if signature already exists
        existing_data = conn.call('HGET', key, signature)
        
        if existing_data
          # Increment count
          parsed = JSON.parse(existing_data)
          parsed['count'] += 1
          conn.call('HSET', key, signature, parsed.to_json)
        else
          # Store new error data
          error_data = {
            type: is_stop_condition ? :stop_condition : :field_error,
            count: 1,
            error: serialized_error,
            definition_id: definition&.id,
            definition_class: definition&.class&.name,
            job_id: job.id,
            job_class: job.class.name,
            details: details.is_a?(Hash) ? details : details.to_h
          }
          conn.call('HSET', key, signature, error_data.to_json)
        end
        
        # Set expiration (1 hour)
        conn.call('EXPIRE', key, 3600)
      end
    end

    def self.store_in_memory(error, definition, job, details)
      # Determine if it's a stop condition or error
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

    def self.fetch_from_redis(job_id)
      Sidekiq.redis do |conn|
        key = "job_completion:errors:#{job_id}"
        all_data = conn.call('HGETALL', key)
        return nil if all_data.empty?

        errors_hash = {}
        # HGETALL returns array of [key, value, key, value, ...]
        all_data.each_slice(2) do |signature, json_data|
          parsed = JSON.parse(json_data)
          # Reconstruct definition and job objects from stored IDs
          definition = find_definition(parsed['definition_class'], parsed['definition_id'])
          job = find_job(parsed['job_class'], parsed['job_id'])
          
          details_hash = parsed['details'] || {}
          details_hash = details_hash.symbolize_keys if details_hash.respond_to?(:symbolize_keys)
          
          errors_hash[signature] = {
            type: parsed['type'].to_sym,
            count: parsed['count'],
            error: parsed['error'], # Keep as serialized, will deserialize later
            definition: definition,
            job: job,
            details: details_hash
          }
        end
        errors_hash
      end
    end

    def self.delete_from_redis(job_id)
      Sidekiq.redis do |conn|
        key = "job_completion:errors:#{job_id}"
        conn.call('DEL', key)
      end
    end

    def self.serialize_error(error)
      return nil unless error
      
      {
        class: error.class.name,
        message: error.message,
        backtrace: error.backtrace&.first(20)
      }
    end

    def self.deserialize_error(error_data)
      return nil unless error_data
      
      # If it's already an error object, return it
      return error_data if error_data.is_a?(Exception) || error_data.is_a?(StandardError)
      
      # If it's a hash/string, reconstruct error
      if error_data.is_a?(Hash) || (error_data.is_a?(String) && error_data.start_with?('{'))
        parsed = error_data.is_a?(Hash) ? error_data : JSON.parse(error_data)
        error_class = parsed['class'] || parsed[:class]
        error_message = parsed['message'] || parsed[:message] || 'Unknown error'
        
        # Create a simple error object
        error_klass = error_class&.constantize rescue StandardError
        error_klass.new(error_message)
      else
        StandardError.new(error_data.to_s)
      end
    end

    def self.find_definition(class_name, id)
      return nil unless class_name && id
      
      klass = class_name.constantize rescue nil
      return nil unless klass
      
      klass.find_by(id: id)
    rescue StandardError
      nil
    end

    def self.find_job(class_name, id)
      return nil unless class_name && id
      
      klass = class_name.constantize rescue nil
      return nil unless klass
      
      klass.find_by(id: id)
    rescue StandardError
      nil
    end

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