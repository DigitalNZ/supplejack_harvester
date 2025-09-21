# frozen_string_literal: true

class JobCompletionSummary < ApplicationRecord
    validates :extraction_id, presence: true, uniqueness: true
    validates :extraction_name, presence: true
    validates :error_type, presence: true
    validates :error_details, presence: true
    validates :error_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
    scope :by_error_type, ->(type) { where(error_type: type) }
    scope :recent, -> { order(last_error_at: :desc) }
    scope :recent_errors, -> { recent }
    scope :with_errors, -> { where('error_count > 0') }
  
    def self.group_by_error_type
      group(:error_type).count
    end
  
    def self.total_errors
      sum(:error_count)
    end
  
    def stop_condition?
      error_type == 'stop condition'
    end
  
    def system_stop_condition?
      stop_condition? && error_details.any? { |detail| detail.dig('details', 'is_system_condition') }
    end
  
    def user_stop_condition?
      stop_condition? && !system_stop_condition?
    end
  
    def self.log_error(extraction_id:, extraction_name:, message:, details: {})
      error_summary = find_or_initialize_by(extraction_id: extraction_id)
  
      error_summary.extraction_name = extraction_name
      error_summary.error_type = 'error'
  
      error_entry = {
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
  
      error_summary.error_details = if error_summary.error_details.present?
                                      error_summary.error_details + [error_entry]
                                    else
                                      [error_entry]
                                    end
  
      error_summary.error_count = error_summary.error_details.size
      error_summary.first_error_at ||= Time.current
      error_summary.last_error_at = Time.current
  
      error_summary.save!
      error_summary
    end
  
    def self.log_stop_condition_hit(extraction_id:, extraction_name:, stop_condition_name:, stop_condition_content:, details: {})
      error_summary = find_or_initialize_by(extraction_id: extraction_id)
  
      error_summary.extraction_name = extraction_name
      error_summary.error_type = 'stop condition'
  
      # Determine if this is a system or user-defined stop condition
      is_system_condition = details[:condition_type].present?
  
      error_entry = {
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
  
      error_summary.error_details = if error_summary.error_details.present?
                                      error_summary.error_details + [error_entry]
                                    else
                                      [error_entry]
                                    end
  
      error_summary.error_count = error_summary.error_details.size
      error_summary.first_error_at ||= Time.current
      error_summary.last_error_at = Time.current
  
      error_summary.save!
      error_summary
    end
  end
  