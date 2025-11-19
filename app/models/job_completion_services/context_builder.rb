# frozen_string_literal: true

module JobCompletionServices
  class ContextBuilder
    def self.create_job_completion_or_error(args)
      context = args[:error].present? ? build_job_error_context(args) : build_job_completion_context(args)

      return if duplicate?(context)

      summary = find_or_create_summary(context)
      create_record(context, summary)
    end

    def self.create_record(context, summary)
      if context[:error].present?
        create_job_error_record(context,
                                summary)
      else
        create_job_completion_record(context, summary)
      end
    end

    def self.build_job_completion_context(args)
      base_context(args, extract_process_info(args[:definition])).merge(
        stop_condition_type: args[:stop_condition_type],
        stop_condition_name: args[:stop_condition_name],
        stop_condition_content: args[:stop_condition_content]
      )
    end

    def self.build_job_error_context(args)
      error = args[:error]
      base_context(args, extract_process_info(args[:definition])).merge(
        error: error, message: MessageBuilder.build_message(error, args[:details] || {}),
        stack_trace: extract_stack_trace(error)
      )
    end

    def self.duplicate?(context)
      exists = context[:error].blank? ? existing_job_completion?(context) : existing_job_error?(context)
      return false unless exists

      find_or_create_summary(context).present?
    end

    def self.existing_job_completion?(context)
      JobCompletion.exists?(job_id: context[:job_id], origin: context[:origin],
                            stop_condition_name: context[:stop_condition_name])
    end

    def self.existing_job_error?(context)
      truncated_message = context[:message]&.slice(0, 255)
      return false unless truncated_message

      JobError.where(job_id: context[:job_id], origin: context[:origin])
              .exists?(['LEFT(message, 255) = ?', truncated_message])
    end

    def self.create_job_completion_record(context, summary)
      JobCompletion.create!(build_job_completion_attributes(context, summary))
    end

    def self.create_job_error_record(context, summary)
      JobError.create!(build_job_error_attributes(context, summary))
    rescue ActiveRecord::RecordNotUnique => e
      handle_duplicate_error(e)
    end

    def self.extract_stack_trace(error)
      return ['No backtrace available'] unless error.respond_to?(:backtrace) && error.backtrace

      error.backtrace.first(1).presence || ['No backtrace available']
    end

    def self.find_or_create_summary(context)
      JobCompletionSummary.find_or_create_by!(job_id: context[:job_id],
                                              process_type: context[:process_type].to_s,
                                              job_type: context[:job_type])
    end

    def self.extract_process_info(definition)
      ProcessInfoBuilder.determine_process_info(definition)
    end

    def self.base_context(args, process_info)
      { origin: args[:origin], job: args[:job], job_id: args[:job].id,
        process_type: process_info[:process_type], job_type: process_info[:job_type] }
    end

    def self.build_job_error_attributes(context, summary)
      { job_completion_summary_id: summary.id, job_id: context[:job_id],
        job_type: context[:job_type], process_type: context[:process_type],
        message: context[:message], stack_trace: context[:stack_trace],
        origin: context[:origin] }
    end

    def self.handle_duplicate_error(error)
      Rails.logger.debug { "JobError duplicate detected (race condition): #{error.message}" }
      nil
    end

    def self.build_job_completion_attributes(context, summary)
      { job_completion_summary_id: summary.id, job_id: context[:job_id],
        process_type: context[:process_type], origin: context[:origin],
        stop_condition_type: context[:stop_condition_type],
        stop_condition_name: context[:stop_condition_name],
        stop_condition_content: context[:stop_condition_content] }
    end
  end
end
