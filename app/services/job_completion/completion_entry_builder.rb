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
        context: details[:context] || {},
        signature: build_entry_signature(message, details)
      }
    end

    def self.build_entry_signature(message, details)
      # Handle both symbol and string keys
      stop_condition_name = details[:stop_condition_name] || details['stop_condition_name']
      
      if stop_condition_name.present?
        # For stop conditions: use type and name
        stop_condition_type = details[:stop_condition_type] || details['stop_condition_type'] || 'unknown'
        "#{stop_condition_type}|#{stop_condition_name}"
      else
        # For errors: use message, stack trace, and field_id
        stack_trace = details[:stack_trace] || details['stack_trace'] || 'no_stack'
        field_id = details[:field_id] || details['field_id'] || 'no_field'
        "#{message}|#{stack_trace}|#{field_id}"
      end
    end
  end
end
