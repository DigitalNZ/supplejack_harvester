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
      existing_entries = completion_summary.completion_entries || []
      entry_signature = completion_entry['signature']
      
      # Check if an entry with the same signature already exists
      existing_entry_index = existing_entries.find_index { |entry| entry['signature'] == entry_signature }
      
      if existing_entry_index
        # Update existing entry: update timestamp and use the maximum count
        existing_entry = existing_entries[existing_entry_index]
        existing_entry['timestamp'] = completion_entry['timestamp']
        # Use the maximum count since both represent total occurrences
        existing_entry['count'] = [existing_entry['count'] || 1, count || 1].max
        completion_entries = existing_entries
      else
        # Add new entry with count
        completion_entry['count'] = count || 1
        completion_entries = existing_entries + [completion_entry]
      end

      completion_summary.assign_attributes(
        source_name: entry_params[:source_name],
        completion_type: completion_type,
        completion_entries: completion_entries,
        completion_count: completion_entries.sum { |entry| entry['count'] || 1 },
        last_completed_at: Time.current
      )

      completion_summary.save!
      completion_summary
    end
  end
end
