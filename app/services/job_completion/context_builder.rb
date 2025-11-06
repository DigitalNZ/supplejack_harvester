# frozen_string_literal: true

module JobCompletion
  class ContextBuilder
    def self.create_job_completion(args)
      origin = args[:origin]
      error = args[:error]
      definition = args[:definition]
      job = args[:job]
      details = args[:details] || {}

      # Extract process information
      process_info = ProcessInfoBuilder.determine_process_info(definition)
      source_id = process_info[:source_id]
      source_name = process_info[:source_name]
      process_type = process_info[:process_type]
      job_type = process_info[:job_type]

      # Determine completion type
      completion_type = determine_completion_type(details)

      # Build message
      message = MessageBuilder.build_message(error, details)

      # Extract stack trace from error (empty array for stop conditions without errors)
      stack_trace = extract_stack_trace(error) || []  

      # Build enhanced details
      enhanced_details = build_enhanced_details(error, job, details, origin)

      # Build context hash (always ensure it's a hash, not nil)
      context = build_context_hash(error, job, details, origin) || {}

      # Find or create JobCompletionSummary (uses enum values)
      job_completion_summary = find_or_create_summary(
        source_id: source_id,
        source_name: source_name,
        process_type: process_type,
        job_type: job_type,
        completion_type: completion_type
      )

      # Convert symbols to integer values for JobCompletion
      process_type_value = convert_process_type_to_integer(process_type)
      completion_type_value = convert_completion_type_to_integer(completion_type)

      # Create JobCompletion record
      JobCompletion.create!(
        job_completion_summary_id: job_completion_summary.id,
        source_id: source_id,
        source_name: source_name,
        process_type: process_type_value,
        job_type: job_type,
        completion_type: completion_type_value,
        message: message,
        stack_trace: stack_trace,
        context: context,
        details: enhanced_details,
        last_completed_at: Time.current
      )
    rescue StandardError => e
      Rails.logger.error "Failed to create job completion: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise
    end

    # Legacy method - kept for backward compatibility
    def self.build_context_from_args(args)
      origin = args[:origin]
      error = args[:error]
      definition = args[:definition]
      job = args[:job]
      details = args[:details] || {}
      count = args[:count] || 1

      process_info = ProcessInfoBuilder.determine_process_info(definition)
      completion_type = determine_completion_type(details)
      message = MessageBuilder.build_message(error, details)
      enhanced_details = build_enhanced_details(error, job, details, origin)

      {
        source_id: process_info[:source_id],
        source_name: process_info[:source_name],
        process_type: process_info[:process_type],
        job_type: process_info[:job_type],
        completion_type: completion_type,
        message: message,
        details: enhanced_details,
        count: count
      }
    end

    private

    def self.extract_stack_trace(error)
      return [] unless error&.respond_to?(:backtrace)
      return [] unless error.backtrace

      error.backtrace&.first(20) || []
    end

    def self.extract_pipeline_job_id(job)
      # HarvestJob has pipeline_job_id directly
      return job.pipeline_job_id if job.respond_to?(:pipeline_job_id) && job.pipeline_job_id
      
      # ExtractionJob might have harvest_job with pipeline_job
      if job.respond_to?(:harvest_job) && job.harvest_job
        return job.harvest_job.pipeline_job_id if job.harvest_job.respond_to?(:pipeline_job_id)
      end
      
      # PipelineJob is itself the pipeline job
      return job.id if job.is_a?(PipelineJob)
      
      nil
    end

    def self.build_enhanced_details(error, job, details, origin)
      enhanced_details = details.dup

      # Add error details if error is present
      if error
        enhanced_details[:exception_class] = error.class.name
        enhanced_details[:exception_message] = error.message
        enhanced_details[:stack_trace] = extract_stack_trace(error)
      end

      # Add job details if job is present
      if job
        enhanced_details[:job_id] = job.id
        enhanced_details[:job_class] = job.class.name
        
        # Extract pipeline_job_id from job (matches old completion_entries structure)
        pipeline_job_id = extract_pipeline_job_id(job)
        enhanced_details[:pipeline_job_id] = pipeline_job_id if pipeline_job_id
      end

      # Add origin if present (matches old completion_entries structure)
      enhanced_details[:origin] = origin if origin.present?

      # Add stop condition details if present
      if details[:stop_condition_name].present?
        enhanced_details[:stop_condition_name] = details[:stop_condition_name]
        enhanced_details[:stop_condition_content] = details[:stop_condition_content]
        enhanced_details[:stop_condition_type] = details[:stop_condition_type]
      end

      enhanced_details
    end

    def self.build_context_hash(error, job, details, origin)
      context = {}
      context[:origin] = origin if origin.present?
      context[:error_class] = error.class.name if error
      context[:job_id] = job.id if job
      context[:job_class] = job.class.name if job
      
      # Extract pipeline_job_id for context (matches old completion_entries structure)
      pipeline_job_id = extract_pipeline_job_id(job) if job
      context[:pipeline_job_id] = pipeline_job_id if pipeline_job_id
      
      context[:timestamp] = Time.current.iso8601
      context
    end

    def self.find_or_create_summary(source_id:, source_name:, process_type:, job_type:, completion_type:)
      # Convert symbols to string enum names for JobCompletionSummary
      process_type_enum = process_type.to_s
      completion_type_enum = completion_type.to_s

      JobCompletionSummary.find_or_create_by!(
        source_id: source_id,
        process_type: process_type_enum,
        job_type: job_type
      ) do |summary|
        summary.source_name = source_name
        summary.completion_type = completion_type_enum
        summary.last_completed_at = Time.current
      end
    end

    def self.determine_completion_type(details)
      details[:stop_condition_name].present? ? :stop_condition : :error
    end

    def self.convert_process_type_to_integer(process_type)
      case process_type
      when :extraction, 'extraction'
        0
      when :transformation, 'transformation'
        1
      else
        # Default to extraction if unknown
        0
      end
    end

    def self.convert_completion_type_to_integer(completion_type)
      case completion_type
      when :error, 'error'
        0
      when :stop_condition, 'stop_condition'
        1
      else
        # Default to error if unknown
        0
      end
    end
  end
end
