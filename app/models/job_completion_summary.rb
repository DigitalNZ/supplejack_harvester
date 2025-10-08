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

  scope :recent_completions, -> { order(last_completed_at: :desc) }

  def self.log_completion(params)
    entry_params = if params[:completion_type] == :stop_condition
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

      completion_entry = build_completion_entry_hash(params[:message], details)
      [completion_entry, process_type, completion_type, job_type, params[:source_id], params[:source_name]]
    end

    def build_completion_entry_hash(message, details)
      {
        message: message,
        details: details,
        timestamp: Time.current.iso8601,
        worker_class: details[:worker_class],
        job_id: details[:job_id],
        pipeline_job_id: details[:pipeline_job_id],
        stack_trace: details[:stack_trace],
        context: details[:context] || {}
      }
    end

    def stop_condition_details(params)
      details = params[:details] || {}
      enhanced_details = build_stop_condition_enhanced_details(details)
      build_completion_hash(params, enhanced_details, :stop_condition)
    end

    def error_details(params)
      details = params[:details] || {}
      build_completion_hash(params, details, :error)
    end

    def build_completion_hash(params, details, completion_type)
      {
        source_id: params[:source_id],
        source_name: params[:source_name],
        message: params[:message],
        details: details,
        job_type: determine_job_type(params, completion_type),
        process_type: determine_process_type(params),
        completion_type: completion_type
      }
    end

    def determine_job_type(params, completion_type)
      params[:job_type] || default_job_type(completion_type)
    end

    def determine_process_type(params)
      params[:process_type] || :extraction
    end

    def build_stop_condition_enhanced_details(details)
      details.merge(
        stop_condition_name: details[:stop_condition_name],
        stop_condition_content: details[:stop_condition_content],
        stop_condition_type: details[:stop_condition_type]
      )
    end

    def default_job_type(completion_type)
      completion_type == :stop_condition ? 'ExtractionJob' : 'Unknown'
    end

    def build_completion_summary(entry_params)
      completion_entry, process_type, completion_type, job_type = build_completion_entry(entry_params)
      completion_summary = find_or_create_completion_summary(entry_params, process_type, job_type)
      update_completion_summary(completion_summary, entry_params, completion_entry, completion_type)
    end

    def find_or_create_completion_summary(entry_params, process_type, job_type)
      find_or_initialize_by(
        source_id: entry_params[:source_id],
        process_type: process_type,
        job_type: job_type
      )
    end

    def update_completion_summary(completion_summary, entry_params, completion_entry, completion_type)
      completion_entries = completion_summary.completion_entries + [completion_entry]

      completion_summary.assign_attributes(
        source_name: entry_params[:source_name],
        completion_type: completion_type,
        completion_entries: completion_entries,
        completion_count: completion_entries.length,
        last_completed_at: Time.current
      )

      completion_summary.save!
      completion_summary
    end
  end
end
