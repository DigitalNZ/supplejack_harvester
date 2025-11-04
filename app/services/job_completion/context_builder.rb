# frozen_string_literal: true

module JobCompletion
  class ContextBuilder
    def self.build_context_from_args(args)
      origin = args[:origin]
      error = args[:error]
      definition = args[:definition]
      job = args[:job]
      details = args[:details] || {}
      # count = args[:count] || 1

      process_info = ProcessInfoBuilder.determine_process_info(definition)
      completion_type = determine_completion_type(details)
      message = MessageBuilder.build_message(error, details)
      enhanced_details = DetailsEnhancer.build_enhanced_details(error, job, details, origin)

      build_final_context(process_info, completion_type, message, enhanced_details)
    end

    def self.build_final_context(process_info, completion_type, message, enhanced_details)
      {
        source_id: process_info[:source_id],
        source_name: process_info[:source_name],
        process_type: process_info[:process_type],
        job_type: process_info[:job_type],
        completion_type: completion_type,
        message: message,
        details: enhanced_details
      }
    end

    def self.determine_completion_type(details)
      details[:stop_condition_name].present? ? :stop_condition : :error
    end
  end
end
