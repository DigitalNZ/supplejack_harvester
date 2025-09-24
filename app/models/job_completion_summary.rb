# frozen_string_literal: true

class JobCompletionSummary < ApplicationRecord
  enum completion_type: {
    error: 0,
    stop_condition: 1
  }

  enum process_type: {
    extraction: 0,
    transformation: 1
  }

  validates :source_id, presence: true
  validates :source_name, presence: true

  validates :job_type, presence: true

  validates :source_id, uniqueness: { scope: %i[process_type job_type] }

  validates :completion_entries, presence: true
  validates :completion_count, presence: true, numericality: { greater_than_or_equal_to: 0 }

  after_initialize :set_defaults, if: :new_record?

  scope :recent_completions, -> { order(last_occurred_at: :desc) }

  def self.log_completion(params)
    entry_params = if params[:completion_type] == 'stop_condition'
                     stop_condition_details(params)
                   else
                     error_details(params)
                   end

    build_completion_summary(entry_params)
  end

  private

  def set_defaults
    self.completion_entries ||= []
    self.completion_count ||= 0
  end

  class << self
    private

    def build_completion_entry(params)
      job_type = params[:job_type]
      process_type = params[:process_type]
      completion_type = params[:completion_type]
      details = params[:details] || {}

      completion_entry = {
        message: params[:message],
        details: details,
        timestamp: Time.current.iso8601,
        worker_class: details[:worker_class],
        job_id: details[:job_id],
        pipeline_job_id: details[:pipeline_job_id],
        stack_trace: details[:stack_trace],
        context: details[:context] || {}
      }

      [completion_entry, process_type, completion_type, job_type]
    end

    def stop_condition_details(params)
      details = params[:details] || {}
      stop_condition_type = details[:stop_condition_type]
      message = params[:message]
      enhanced_details = details.merge(
        stop_condition_name: details[:stop_condition_name],
        stop_condition_content: details[:stop_condition_content],
        stop_condition_type: stop_condition_type
      )

      {
        message: message,
        details: enhanced_details,
        job_type: 'ExtractionJob',
        process_type: :extraction,
        completion_type: :stop_condition
      }
    end

    def error_details(params)
      details = params[:details] || {}
      process_type = params[:process_type] || :extraction
      job_type = params[:job_type] || 'Unknown'
      message = params[:message]

      {
        message: message,
        details: details,
        job_type: job_type,
        process_type: process_type,
        completion_type: :error
      }
    end

    def build_completion_summary(entry_params)
      completion_entry, process_type, completion_type, job_type = build_completion_entry(entry_params)

      # Check for existing summary
      completion_summary = find_or_initialize_by(
        source_id: entry_params[:source_id],
        process_type: process_type,
        job_type: job_type
      )

      # Add new completion entry (a error or stop condition)
      completion_entries = completion_summary.completion_entries + [completion_entry]

      # Update completion summary
      completion_summary.assign_attributes(
        source_name: entry_params[:source_name],
        completion_type: completion_type,
        completion_entries: completion_entries,
        completion_count: completion_entries.length,
        last_occurred_at: Time.current
      )

      completion_summary.save!
      completion_summary
    end
  end
end
