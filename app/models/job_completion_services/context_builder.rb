# frozen_string_literal: true

module JobCompletionServices
  class ContextBuilder
    def self.create_job_completion(args)
      origin = args[:origin]
      error = args[:error]
      definition = args[:definition]
      job = args[:job]
      details = args[:details] || {}

      source_id, source_name, process_type, job_type = extract_process_info(definition)
      process_type_string = process_type.to_s

      # Build message early so we can check for exact error match
      completion_type = determine_completion_type(details)
      message = MessageBuilder.build_message(error, details)
      message_prefix = message[0..49]  # First 50 characters

      # Check to see if there is an existing job completion for the same source, process, job, origin, AND message
      # if so, update the count and return 
      if is_existing_job_completion?(source_id, process_type, job_type, origin, message_prefix)
        Rails.logger.info "Existing job completion found for source_id: #{source_id}, process_type: #{process_type_string}, job_type: #{job_type}, origin: #{origin}, message_prefix: #{message_prefix}"
        current_job_competion_summary = JobCompletionSummary.find_by(source_id: source_id, process_type: process_type_string, job_type: job_type)
        return if current_job_competion_summary.nil?

        # Increment the completion count 
        current_job_competion_summary.increment_completion_count
        current_job_competion_summary.touch # updated_at
        current_job_competion_summary.save!
        
        return
      end

      stack_trace = extract_stack_trace(error) || []  
      enhanced_details = build_enhanced_details(error, job, details, origin)
      context = build_context_hash(error, job, details, origin) || {}

      # Find or create JobCompletionSummary (uses enum values)
      job_completion_summary = find_or_create_summary(
        source_id: source_id,
        source_name: source_name,
        process_type: process_type,
        job_type: job_type,
        completion_type: completion_type
      )

      # Create JobCompletion record (enums accept symbols/strings directly)
      JobCompletion.create!(
        source_id: source_id,
        source_name: source_name,
        process_type: process_type,
        job_type: job_type,
        completion_type: completion_type,
        message: message,
        message_prefix: message_prefix,
        origin: origin,
        stack_trace: stack_trace,
        context: context,
        details: enhanced_details
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

    def self.is_existing_job_completion?(source_id, process_type, job_type, origin, message_prefix)
      JobCompletion.where(
        source_id: source_id,
        process_type: process_type,
        job_type: job_type,
        origin: origin,
        message_prefix: message_prefix
      ).exists?
    end

    def self.extract_stack_trace(error)
      return [] unless error&.respond_to?(:backtrace)
      return [] unless error.backtrace

      # only take the first line of the stack traceev
      error.backtrace&.first(1) || []
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
      process_type_enum = process_type.to_s
      completion_type_enum = completion_type.to_s

      JobCompletionSummary.find_or_create_by!(
        source_id: source_id,
        process_type: process_type_enum,
        job_type: job_type
      ) do |summary|
        summary.source_name = source_name
        summary.completion_type = completion_type_enum
      end
    end

    def self.determine_completion_type(details)
      details[:stop_condition_name].present? ? :stop_condition : :error
    end

    def self.extract_process_info(definition)
      process_info = ProcessInfoBuilder.determine_process_info(definition)
      source_id = process_info[:source_id]
      source_name = process_info[:source_name]
      process_type = process_info[:process_type]
      job_type = process_info[:job_type]

      return source_id, source_name, process_type, job_type
    end
  end
end
