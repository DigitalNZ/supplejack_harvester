# frozen_string_literal: true

module JobCompletion
  class CompletionEntryBuilder
    def self.build_completion_entry(params)
      job_type = params[:job_type]
      process_type = params[:process_type]
      completion_type = params[:completion_type]
      details = params[:details] || {}

      completion_entry = build_completion_entry_hash(params[:message], details)
      [completion_entry, process_type, completion_type, job_type, params[:source_id], params[:source_name]]
    end

    def self.build_completion_entry_hash(message, details)
      {
        message: message,
        details: details,
        timestamp: Time.current.iso8601,
        origin: details[:origin],
        job_id: details[:job_id],
        pipeline_job_id: details[:pipeline_job_id],
        stack_trace: details[:stack_trace],
        context: details[:context] || {}
      }
    end
  end
end
