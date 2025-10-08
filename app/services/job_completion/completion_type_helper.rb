# frozen_string_literal: true

module JobCompletion
  class CompletionTypeHelper
    def self.determine_job_type(params, completion_type)
      params[:job_type] || default_job_type(completion_type)
    end

    def self.determine_process_type(params)
      params[:process_type] || :extraction
    end

    def self.default_job_type(completion_type)
      completion_type == :stop_condition ? 'ExtractionJob' : 'Unknown'
    end
  end
end
