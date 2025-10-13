# frozen_string_literal: true

module JobCompletion
  class Logger
    def self.log_completion(args)
      context = ContextBuilder.build_context_from_args(args)
      CompletionSummaryBuilder.build_completion_summary(context)
    rescue StandardError => e
      Rails.logger.error "Failed to log completion: #{e.message}"
    end
  end
end
