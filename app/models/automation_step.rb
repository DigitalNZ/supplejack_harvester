# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class AutomationStep < ApplicationRecord
  include StatusManagement
  include HarvestDefinitionLookup

  belongs_to :automation
  belongs_to :pipeline, optional: true
  belongs_to :launched_by, class_name: 'User', optional: true
  belongs_to :extraction_definition, optional: true
  belongs_to :pre_extraction_job, class_name: 'ExtractionJob', optional: true
  has_one :pipeline_job, dependent: :destroy
  has_one :api_response_report, class_name: 'ApiResponseReport', dependent: :destroy

  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :pipeline_id, presence: true, if: -> { step_type == 'pipeline' }
  validates :api_url, :api_method, presence: true, if: -> { step_type == 'api_call' }
  validates :extraction_definition_id, presence: true, if: -> { step_type == 'pre_extraction' }
  validate :validate_step_type_requirements

  serialize :harvest_definition_ids, type: Array

  API_METHODS = %w[GET POST PUT PATCH DELETE].freeze

  # :reek:RepeatedConditional - step_type dispatch is intentional for clarity
  def display_name
    display_position = position + 1

    case step_type
    when 'api_call'
      "#{display_position}. API Call: #{api_method} #{api_url}"
    when 'pre_extraction'
      "#{display_position}. Pre-Extraction: #{extraction_definition&.name || 'Unknown'}"
    else
      "#{display_position}. #{pipeline&.name || 'Unknown Pipeline'}"
    end
  end

  # Returns the status of this step
  # Prioritizes statuses in a logical order
  def status
    case step_type
    when 'api_call'
      api_call_status
    when 'pre_extraction'
      pre_extraction_status
    else
      pipeline_status
    end
  end

  def api_call_status
    return 'not_started' unless api_response_report

    api_response_report.status
  end

  def pre_extraction_status
    return 'not_started' unless pre_extraction_job

    pre_extraction_job.status
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

  # Execute pre-extraction by creating and queuing extraction job
  def execute_pre_extraction
    return if pre_extraction_job.present?

    extraction_job = create_pre_extraction_job
    extraction_job.update(status: 'queued') if extraction_job.status.blank?

    update(pre_extraction_job_id: extraction_job.id)
    ExtractionWorker.perform_async_with_priority(automation.job_priority, extraction_job.id)
  end

  def create_pre_extraction_job
    ExtractionJob.create(
      extraction_definition: extraction_definition,
      kind: 'full',
      pre_extraction_job_id: find_previous_pre_extraction_job_id,
      is_pre_extraction: true
    )
  end

  def find_previous_pre_extraction_job_id
    previous_pre_extraction_step = automation.automation_steps
                                             .where('position < ?', position)
                                             .where(step_type: 'pre_extraction')
                                             .order(position: :desc)
                                             .first

    previous_pre_extraction_step&.pre_extraction_job_id
  end

  private

  def validate_step_type_requirements
    case step_type
    when 'pipeline'
      validate_pipeline_requirements
    when 'api_call'
      validate_api_call_requirements
    when 'pre_extraction'
      validate_pre_extraction_requirements
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

  def validate_pre_extraction_requirements
    errors.add(:extraction_definition_id, "can't be blank") if extraction_definition_id.blank?
  end

  def no_reports?
    case step_type
    when 'api_call'
      api_response_report.blank?
    when 'pre_extraction'
      pre_extraction_job.blank?
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
# rubocop:enable Metrics/ClassLength
