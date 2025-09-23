# frozen_string_literal: true

class JobCompletionSummary < ApplicationRecord
  enum completion_type: {
    error: 0,
    stop_condition: 1
  }

  validates :extraction_id, presence: true, uniqueness: true
  validates :extraction_name, presence: true
  validates :completion_details, presence: true
  validates :completion_count, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :by_completion_type, ->(type) { where(completion_type: type) }
  scope :recent_completions, -> { order(last_occurred_at: :desc) }
  scope :with_completions, -> { where('completion_count > 0') }

  def self.group_by_completion_type
    group(:completion_type).count
  end

  def self.total_completions
    sum(:completion_count)
  end

  def system_stop_condition?
    return false unless stop_condition?

    last_entry = completion_details.last
    last_entry&.dig('details', 'is_system_condition') == true
  end

  def user_stop_condition?
    stop_condition? && !system_stop_condition?
  end

  def self.create_completion_summary(completion_entry, extraction_id, extraction_name, completion_type)
    completion_summary = find_or_initialize_by(extraction_id: extraction_id)

    completion_summary.extraction_name = extraction_name
    completion_summary.completion_type = completion_type

    existing_details = completion_summary.completion_details || []
    new_details = existing_details + [completion_entry]

    completion_summary.completion_details = new_details
    completion_summary.completion_count = new_details.length
    completion_summary.last_occurred_at = Time.current
    completion_summary.save!
    completion_summary
  end

  def self.log_completion(extraction_id:, extraction_name:, message:, details: {})
    completion_entry = {
      message: message,
      details: details,
      timestamp: Time.current.iso8601,
      worker_class: details[:worker_class],
      job_id: details[:job_id],
      harvest_job_id: details[:harvest_job_id],
      pipeline_job_id: details[:pipeline_job_id],
      harvest_report_id: details[:harvest_report_id],
      stack_trace: details[:stack_trace],
      context: details[:context] || {}
    }

    create_completion_summary(completion_entry, extraction_id, extraction_name, :error)
  end

  def self.log_stop_condition_hit(params)
    extraction_id = params[:extraction_id]
    extraction_name = params[:extraction_name]
    stop_condition_name = params[:stop_condition_name]
    stop_condition_content = params[:stop_condition_content]
    details = params[:details] || {}
    condition_type = details[:condition_type]
    is_system_condition = condition_type.present? && condition_type != 'user'

    completion_entry = {
      message: if is_system_condition
                 "System stop condition '#{stop_condition_name}' was triggered"
               else
                 "Stop condition '#{stop_condition_name}' was triggered"
               end,
      details: details.merge(
        stop_condition_name: stop_condition_name,
        stop_condition_content: stop_condition_content,
        is_system_condition: is_system_condition
      ),
      timestamp: Time.current.iso8601
    }

    create_completion_summary(completion_entry, extraction_id, extraction_name, :stop_condition)
  end
end
