# frozen_string_literal: true

module JobCompletion
  class CompletionDetailsBuilder
    def self.stop_condition_details(params)
      details = params[:details] || {}
      enhanced_details = build_stop_condition_enhanced_details(details)
      build_completion_hash(params, enhanced_details, :stop_condition)
    end

    def self.error_details(params)
      details = params[:details] || {}
      build_completion_hash(params, details, :error)
    end

    def self.build_completion_hash(params, details, completion_type)
      {
        source_id: params[:source_id],
        source_name: params[:source_name],
        message: params[:message],
        details: details,
        job_type: CompletionTypeDeterminer.determine_job_type(params, completion_type),
        process_type: CompletionTypeDeterminer.determine_process_type(params),
        completion_type: completion_type
      }
    end

    def self.build_stop_condition_enhanced_details(details)
      details.merge(
        stop_condition_name: details[:stop_condition_name],
        stop_condition_content: details[:stop_condition_content],
        stop_condition_type: details[:stop_condition_type]
      )
    end
  end
end
