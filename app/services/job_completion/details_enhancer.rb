# frozen_string_literal: true

module JobCompletion
  class DetailsEnhancer
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
