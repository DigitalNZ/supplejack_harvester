# frozen_string_literal: true

module JobCompletion
  class CompletionSummaryBuilder
    def self.build_completion_summary(entry_params)
      # count = entry_params[:count] || 1  # Extract from entry_params instead
      completion_entry, process_type, completion_type, job_type =
        CompletionEntryBuilder.build_completion_entry(entry_params)
      completion_summary = CompletionSummaryManager.find_or_create_completion_summary(entry_params, process_type,
                                                                                      job_type)
      CompletionSummaryManager.update_completion_summary(completion_summary, entry_params, completion_entry,
                                                         completion_type)
    end
  end
end
