# frozen_string_literal: true

module JobCompletionServices
  class ContextBuilder
    def self.create_job_completion(args)
      context = build_context(args)

      return if handle_duplicate_completion(context)

      create_new_completion(context)
    rescue StandardError => e
      log_error(e)
      raise
    end

    def self.build_context(args)
      details = args[:details] || {}
      error = args[:error]
      process_info = extract_process_info(args[:definition])

      {
        origin: args[:origin],
        error: error,
        job: args[:job],
        details: details,
        source_id: process_info[:source_id],
        source_name: process_info[:source_name],
        process_type: process_info[:process_type],
        job_type: process_info[:job_type],
        completion_type: determine_completion_type(details),
        message: MessageBuilder.build_message(error, details),
        message_prefix: nil # Will be set after message is built
      }
    end

    def self.handle_duplicate_completion(context)
      context[:message_prefix] = context[:message][0..49]

      return false unless is_existing_job_completion?(context)

      summary = find_or_create_summary(context)
      return false unless summary

      increment_summary_count(summary, context)
      true
    end

    def self.is_existing_job_completion?(context)
      JobCompletion.exists?(source_id: context[:source_id],
                            process_type: context[:process_type],
                            job_type: context[:job_type],
                            origin: context[:origin],
                            message_prefix: context[:message_prefix])
    end

    def self.increment_summary_count(summary, context)
      logger = Rails.logger
      logger.info "Existing job completion found for source_id: #{context[:source_id]}, " \
                  "process_type: #{context[:process_type]}, job_type: #{context[:job_type]}, " \
                  "origin: #{context[:origin]}, message_prefix: #{context[:message_prefix]}"

      summary.increment_completion_count
      summary.touch
      summary.save!
    end

    def self.create_new_completion(context)
      context[:message_prefix] = context[:message][0..49]
      context[:stack_trace] = extract_stack_trace(context[:error]) || []
      context[:enhanced_details] = build_enhanced_details(context)

      summary = find_or_create_summary(context)
      create_job_completion_record(context, summary)
    end

    def self.create_job_completion_record(context, _summary)
      JobCompletion.create!(
        source_id: context[:source_id],
        source_name: context[:source_name],
        process_type: context[:process_type],
        job_type: context[:job_type],
        completion_type: context[:completion_type],
        message: context[:message],
        message_prefix: context[:message_prefix],
        origin: context[:origin],
        stack_trace: context[:stack_trace],
        details: context[:enhanced_details]
      )
    end

    def self.extract_stack_trace(error)
      return [] unless error.respond_to?(:backtrace)

      backtrace = error.backtrace
      return [] unless backtrace

      # only take the first line - harvesters don't need the full stack trace
      backtrace.first(1) || []
    end

    def self.extract_pipeline_job_id(job)
      pipeline_job_id = job.pipeline_job_id if job.respond_to?(:pipeline_job_id)
      return pipeline_job_id if pipeline_job_id

      harvest_job = job.harvest_job if job.respond_to?(:harvest_job)
      return harvest_job.pipeline_job_id if harvest_job.respond_to?(:pipeline_job_id)

      return job.id if job.is_a?(PipelineJob)

      nil
    end

    def self.build_enhanced_details(context)
      details = context[:details]
      enhanced_details = details.dup
      error = context[:error]
      job = context[:job]
      origin = context[:origin]

      add_error_details(enhanced_details, error) if error
      add_job_details(enhanced_details, job) if job
      add_origin_and_timestamp(enhanced_details, origin)
      add_stop_condition_details(enhanced_details, details)

      enhanced_details
    end

    def self.add_error_details(enhanced_details, error)
      enhanced_details[:exception_class] = error.class.name
      enhanced_details[:exception_message] = error.message
      enhanced_details[:stack_trace] = extract_stack_trace(error)
    end

    def self.add_job_details(enhanced_details, job)
      enhanced_details[:job_id] = job.id
      enhanced_details[:job_class] = job.class.name

      pipeline_job_id = extract_pipeline_job_id(job)
      enhanced_details[:pipeline_job_id] = pipeline_job_id if pipeline_job_id
    end

    def self.add_origin_and_timestamp(enhanced_details, origin)
      enhanced_details[:origin] = origin if origin.present?
      enhanced_details[:timestamp] = Time.current.iso8601
    end

    def self.add_stop_condition_details(enhanced_details, details)
      stop_condition_name = details[:stop_condition_name]
      return if stop_condition_name.blank?

      enhanced_details[:stop_condition_name] = stop_condition_name
      enhanced_details[:stop_condition_content] = details[:stop_condition_content] # information for user defined stop conditions
      enhanced_details[:stop_condition_type] = details[:stop_condition_type]
    end

    def self.find_or_create_summary(context)
      JobCompletionSummary.find_or_create_by!(
        source_id: context[:source_id],
        process_type: context[:process_type].to_s,
        job_type: context[:job_type]
      ) do |summary|
        summary.source_name = context[:source_name]
      end
    end

    def self.determine_completion_type(details)
      details[:stop_condition_name].present? ? :stop_condition : :error
    end

    def self.extract_process_info(definition)
      ProcessInfoBuilder.determine_process_info(definition)
    end

    def self.log_error(error)
      logger = Rails.logger
      logger.error "Failed to create job completion: #{error.message}"
      logger.error error.backtrace.join("\n")
    end
  end
end
