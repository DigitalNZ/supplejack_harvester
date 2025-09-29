# frozen_string_literal: true

module JobCompletion
  class CompletionSummaryBuilder
    def self.build_completion_summary(entry_params)
      completion_entry, process_type, completion_type, job_type = CompletionEntryBuilder.build_completion_entry(entry_params)
      completion_summary = CompletionSummaryRepository.find_or_create_completion_summary(entry_params, process_type, job_type)
      CompletionSummaryRepository.update_completion_summary(completion_summary, entry_params, completion_entry, completion_type)
    end
  end
end
