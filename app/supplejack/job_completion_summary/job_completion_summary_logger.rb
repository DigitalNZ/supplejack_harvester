# frozen_string_literal: true

module JobCompletionSummary
  class Logger
    def self.log_completion(args)
      context = build_context_from_args(args)

      JobCompletionSummary.log_completion(context)
    rescue StandardError => e
      Rails.logger.error "Failed to log completion to JobCompletionSummary: #{e.message}"
    end

    def self.build_context_from_args(args)
      error = args[:error]
      definition = args[:definition]
      job = args[:job]
      details = args[:details] || {}

      process_info = determine_process_info(definition)
      completion_type = determine_completion_type(details)
      message = build_message(error, details)
      enhanced_details = build_enhanced_details(error, job, details)

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

    def self.determine_process_info(definition)
      if definition.is_a?(ExtractionDefinition)
        build_extraction_process_info(definition)
      elsif definition.is_a?(TransformationDefinition)
        build_transformation_process_info(definition)
      else
        raise "Invalid definition type: #{definition.class.name}"
      end
    end

    def self.build_extraction_process_info(definition)
      harvest_definition = definition.harvest_definitions.first
      {
        process_type: :extraction,
        job_type: 'ExtractionJob',
        source_id: harvest_definition&.source_id || 'unknown',
        source_name: harvest_definition&.name || 'unknown'
      }
    end

    def self.build_transformation_process_info(definition)
      harvest_definition = definition.harvest_definitions.first
      {
        process_type: :transformation,
        job_type: 'TransformationJob',
        source_id: harvest_definition&.source_id || 'unknown',
        source_name: harvest_definition&.name || 'unknown'
      }
    end

    def self.determine_completion_type(details)
      details[:stop_condition_name].present? ? :stop_condition : :error
    end

    def self.build_message(error, details)
      if details[:stop_condition_name].present?
        build_stop_condition_message(details)
      else
        build_error_message(error)
      end
    end

    def self.build_stop_condition_message(details)
      if details[:stop_condition_type] == 'user'
        "Stop condition '#{details[:stop_condition_name]}' was triggered"
      else
        "System stop condition '#{details[:stop_condition_name]}' was triggered"
      end
    end

    def self.build_error_message(error)
      error ? "#{error.class.name}: #{error.message}" : 'Unknown error occurred'
    end

    def self.build_enhanced_details(error, job, details)
      enhanced_details = {}
      add_error_details(enhanced_details, error) if error
      add_job_details(enhanced_details, job)
      add_stop_condition_details(enhanced_details, details)
      add_additional_details(enhanced_details, details)
      enhanced_details
    end

    def self.add_error_details(enhanced_details, error)
      enhanced_details.merge!(
        exception_class: error.class.name,
        exception_message: error.message,
        stack_trace: error.backtrace&.first(20)
      )
    end

    def self.add_job_details(enhanced_details, job)
      enhanced_details[:job_id] = job&.id
    end

    def self.add_stop_condition_details(enhanced_details, details)
      return if details[:stop_condition_name].blank?

      enhanced_details.merge!(
        stop_condition_name: details[:stop_condition_name],
        stop_condition_content: details[:stop_condition_content],
        stop_condition_type: details[:stop_condition_type]
      )
    end

    def self.add_additional_details(enhanced_details, details)
      enhanced_details.merge!(
        details.except(:stop_condition_name, :stop_condition_content, :stop_condition_type)
      )
    end
  end
end
