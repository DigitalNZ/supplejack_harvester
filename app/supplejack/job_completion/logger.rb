# frozen_string_literal: true

module JobCompletion
  class Logger
    # Legacy method - kept for backward compatibility but now stores to Redis
    def self.log_completion(args)
      store_completion(
        error: args[:error],
        definition: args[:definition],
        job: args[:job],
        details: args[:details] || {},
        origin: args[:origin]
      )
    rescue StandardError => e
      Rails.logger.error "Failed to log completion: #{e.message}"
    end

    # Store completion context in Redis instead of immediately writing to DB
    def self.store_completion(error:, definition:, job:, details: {}, origin: nil)
      context = ContextBuilder.build_context_from_args(
        error: error,
        definition: definition,
        job: job,
        details: details,
        origin: origin
      )

      process_type = context[:process_type]
      job_id = determine_job_id(job, process_type)

      RedisStorage.store_completion_context(job_id, process_type, context)
    rescue StandardError => e
      Rails.logger.error "Failed to store completion in Redis: #{e.message}"
    end

    # Wrapper for field errors
    def self.store_field_error(error, definition, job, details = {})
      store_completion(
        error: error,
        definition: definition,
        job: job,
        details: details,
        origin: 'FieldExecution'
      )
    end

    # Wrapper for stop conditions
    def self.store_stop_condition(error, definition, job, details = {})
      store_completion(
        error: error,
        definition: definition,
        job: job,
        details: details,
        origin: 'ExtractionExecution'
      )
    end

    # Update completion summary with all accumulated errors from Redis
    def self.update_summary_with_accumulated_errors(job_id)
      # Try both extraction and transformation process types
      %i[extraction transformation].each do |process_type|
        contexts = RedisStorage.get_all_contexts(job_id, process_type)
        next if contexts.empty?

        process_contexts(contexts, process_type)
        RedisStorage.clear_completion_contexts(job_id, process_type)
      end
    rescue StandardError => e
      Rails.logger.error "Failed to update summary with accumulated errors: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end

    private

    def self.process_contexts(contexts, process_type)
      # Group contexts by signature to aggregate counts
      grouped_contexts = contexts.group_by do |context|
        # Build a temporary entry to get signature
        temp_entry, = CompletionEntryBuilder.build_completion_entry(context)
        temp_entry['signature']
      end

      # Process each group and aggregate counts
      grouped_contexts.each do |_signature, group|
        aggregate_and_update_summary(group)
      end
    end

    def self.aggregate_and_update_summary(contexts)
      # Use first context for entry params (they should all be the same except count)
      entry_params = contexts.first.dup
      count = contexts.count

      # Build completion entry and update summary
      completion_entry, process_type_from_entry, completion_type, job_type =
        CompletionEntryBuilder.build_completion_entry(entry_params)

      completion_summary = CompletionSummaryManager.find_or_create_completion_summary(
        entry_params,
        process_type_from_entry,
        job_type
      )

      CompletionSummaryManager.update_completion_summary(
        completion_summary,
        entry_params,
        completion_entry,
        completion_type,
        count
      )
    end

    def self.determine_job_id(job, process_type)
      return nil unless job

      case process_type
      when :extraction
        # For extraction, job is ExtractionJob
        job.id
      when :transformation
        # For transformation, job should be HarvestJob
        # If we get an ExtractionJob, find its harvest_job
        if job.is_a?(HarvestJob)
          job.id
        elsif job.is_a?(ExtractionJob)
          job.harvest_job&.id || job.id
        elsif job.is_a?(PipelineJob)
          # PipelineJob has many harvest_jobs, try to get the first one
          # This is a fallback - ideally workers should pass HarvestJob
          job.harvest_jobs.first&.id || job.id
        else
          job.id
        end
      else
        job.id
      end
    end
  end
end
