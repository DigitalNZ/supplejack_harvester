# frozen_string_literal: true

module JobCompletionServices
  class ContextBuilder
    def self.create_job_completion_or_error(args)
      context = args[:error].present? ? build_job_error_context(args) : build_job_completion_context(args)

      return if is_duplicate?(context)

      summary = find_or_create_summary(context)
      create_record(context, summary)
    end

    def self.create_record(context, summary)
      if context[:error].present?
        create_job_error_record(context, summary)
      else
        create_job_completion_record(context, summary)
      end
    end

    def self.build_job_completion_context(args)
      stop_condition_type = args[:stop_condition_type]
      stop_condition_name = args[:stop_condition_name]
      stop_condition_content = args[:stop_condition_content]
      process_info = extract_process_info(args[:definition])

      {
        origin: args[:origin],
        job: args[:job],
        job_id: args[:job].id,
        process_type: process_info[:process_type],
        job_type: process_info[:job_type],
        stop_condition_type: stop_condition_type,
        stop_condition_name: stop_condition_name,
        stop_condition_content: stop_condition_content
      }
    end

    def self.build_job_error_context(args)
      details = args[:details] || {}
      error = args[:error]
      process_info = extract_process_info(args[:definition])
      message = MessageBuilder.build_message(error, details)
      stack_trace = extract_stack_trace(error) || []

      {
        origin: args[:origin],
        error: error,
        job: args[:job],
        job_id: args[:job].id,
        process_type: process_info[:process_type],
        job_type: process_info[:job_type],
        message: message,
        stack_trace: stack_trace
      }
    end

    def self.is_duplicate?(context)
      exists = if context[:error].blank?
                 is_existing_job_completion?(context)
               else
                 is_existing_job_error?(context)
               end

      return false unless exists

      summary = find_or_create_summary(context)
      summary.present?
    end

    def self.is_existing_job_completion?(context)
      JobCompletion.exists?(job_id: context[:job_id],
                            origin: context[:origin],
                            stop_condition_name: context[:stop_condition_name])
    end

    def self.is_existing_job_error?(context)
      # Truncate message to 255 chars to match MySQL index length
      # Use SQL LEFT function to compare truncated messages
      truncated_message = context[:message]&.slice(0, 255)
      return false unless truncated_message

      JobError.where(job_id: context[:job_id], origin: context[:origin])
              .exists?(['LEFT(message, 255) = ?', truncated_message])
    end

    def self.create_job_completion_record(context, summary)
      JobCompletion.create!(
        job_completion_summary_id: summary.id,
        job_id: context[:job_id],
        process_type: context[:process_type],
        origin: context[:origin],
        stop_condition_type: context[:stop_condition_type],
        stop_condition_name: context[:stop_condition_name],
        stop_condition_content: context[:stop_condition_content]
      )
    end

    def self.create_job_error_record(context, summary)
      JobError.create!(
        job_completion_summary_id: summary.id,
        job_id: context[:job_id],
        job_type: context[:job_type],
        process_type: context[:process_type],
        message: context[:message],
        stack_trace: context[:stack_trace],
        origin: context[:origin]
      )
    rescue ActiveRecord::RecordNotUnique => e
      # Handle race condition where duplicate check passed but insert failed
      # This is fine - the record already exists, so we can silently return
      Rails.logger.debug { "JobError duplicate detected (race condition): #{e.message}" }
      nil
    end

    def self.extract_stack_trace(error)
      return [] unless error.respond_to?(:backtrace)

      backtrace = error.backtrace
      return [] unless backtrace

      # Only take the first line. Harvesters don't need the full stack trace
      backtrace.first(1) || []
    end

    def self.find_or_create_summary(context)
      JobCompletionSummary.find_or_create_by!(
        job_id: context[:job_id],
        process_type: context[:process_type].to_s,
        job_type: context[:job_type]
      )
    end

    def self.extract_process_info(definition)
      ProcessInfoBuilder.determine_process_info(definition)
    end
  end
end
