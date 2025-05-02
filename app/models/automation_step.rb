# frozen_string_literal: true

class AutomationStep < ApplicationRecord
  include StatusManagement

  belongs_to :automation
  belongs_to :pipeline, optional: true
  belongs_to :launched_by, class_name: 'User', optional: true
  has_one :pipeline_job, dependent: :destroy
  has_one :api_response_report, class_name: 'ApiResponseReport', dependent: :destroy

  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :pipeline_id, presence: true, if: -> { step_type == 'pipeline' }
  validates :api_url, :api_method, presence: true, if: -> { step_type == 'api_call' }
  validate :validate_step_type_requirements

  serialize :harvest_definition_ids, type: Array

  API_METHODS = %w[GET POST PUT PATCH DELETE].freeze

  def harvest_definitions
    return [] unless pipeline
    return Pipeline.find(pipeline_id).harvest_definitions if harvest_definition_ids.blank?

    HarvestDefinition.where(id: harvest_definition_ids)
  end

  def display_name
    case step_type
    when 'api_call'
      "#{position + 1}. API Call: #{api_method} #{api_url}"
    else
      "#{position + 1}. #{pipeline&.name || 'Unknown Pipeline'}"
    end
  end

  # Returns the status of this step
  # Prioritizes statuses in a logical order
  def status
    case step_type
    when 'api_call'
      api_call_status
    else
      pipeline_status
    end
  end

  def api_call_status
    return 'not_started' unless api_response_report

    api_response_report.status
  end

  def pipeline_status
    return 'not_started' if no_reports?

    statuses = report_statuses
    status_from_statuses(statuses)
  end

  def next_step
    automation.automation_steps.where('position > ?', position).order(position: :asc).first
  end

  # Get destination from the automation
  delegate :destination, to: :automation

  # For compatibility with existing code that might expect destination_id
  def destination_id
    destination&.id
  end

  # Execute the API call by enqueuing the job
  def execute_api_call
    # Create an initial API response report to show queued status
    if api_response_report.blank?
      create_api_response_report(
        status: 'queued',
        response_code: nil,
        response_body: nil,
        response_headers: nil,
        executed_at: nil
      )
    end

    # Enqueue the API call job
    ApiCallWorker.perform_in_with_priority(automation.job_priority, 5.seconds, id)
  end

  private

  def validate_step_type_requirements
    case step_type
    when 'pipeline'
      validate_pipeline_requirements
    when 'api_call'
      validate_api_call_requirements
    end
  end

  def validate_pipeline_requirements
    errors.add(:pipeline_id, "can't be blank") if pipeline_id.blank?
  end

  def validate_api_call_requirements
    errors.add(:api_url, "can't be blank") if api_url.blank?
    errors.add(:api_method, "can't be blank") if api_method.blank?
    errors.add(:pipeline_id, 'must be blank for API calls') if pipeline_id.present?
  end

  def no_reports?
    if step_type == 'api_call'
      api_response_report.blank?
    else
      pipeline_job&.harvest_reports&.blank?
    end
  end

  def report_statuses
    return [] unless pipeline_job

    reports = pipeline_job.harvest_reports
    reports&.map(&:status)&.uniq || []
  end
end
