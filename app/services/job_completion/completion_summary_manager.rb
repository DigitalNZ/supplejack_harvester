# frozen_string_literal: true

module JobCompletion
  class CompletionSummaryManager
    def self.find_or_create_completion_summary(entry_params, process_type, job_type)
      JobCompletionSummary.find_or_initialize_by(
        source_id: entry_params[:source_id],
        process_type: process_type,
        job_type: job_type
      )
    end

    def self.update_completion_summary(completion_summary, entry_params, completion_entry, completion_type, count)
      completion_entries = completion_summary.completion_entries + [completion_entry]

      completion_summary.assign_attributes(
        source_name: entry_params[:source_name],
        completion_type: completion_type,
        completion_entries: completion_entries,
        completion_count: count,
        last_completed_at: Time.current
      )

      completion_summary.save!
      completion_summary
    end
  end
end
