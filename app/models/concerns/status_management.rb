# frozen_string_literal: true

# Comprehensive status management for models that need to compute and check statuses
module StatusManagement
  extend ActiveSupport::Concern

  # Status check in priority order - first match wins
  STATUS_PRIORITY = {
    'not_started' => :not_started?,
    'cancelled' => :cancelled?,
    'completed' => :completed?,
    'errored' => :errored?,
    'failed' => :failed?,
    'running' => :running?,
    'queued' => :queued?
  }.freeze

  def status_from_statuses(statuses)
    STATUS_PRIORITY.each do |status, method_name|
      return status if can_check_status?(method_name) && send(method_name, statuses)
    end

    'running' # Default status if no conditions match
  end

  private

  def can_check_status?(method_name)
    respond_to?(method_name, true)
  end

  # Common status check methods

  def not_started?(statuses)
    statuses.blank? || statuses.include?('not_started')
  end

  def cancelled?(statuses)
    statuses.include?('cancelled')
  end

  def completed?(statuses)
    statuses.all?('completed')
  end

  def errored?(statuses)
    statuses.include?('errored')
  end

  def running?(statuses)
    statuses.include?('running')
  end

  def queued?(statuses)
    statuses.include?('queued')
  end

  # Report checking functionality

  def step_has_report?(step)
    case step.step_type
    when 'api_call'
      step.api_response_report.present?
    when 'independent_extraction'
      step.independent_extraction_job.present?
    else
      step.pipeline_job.present? && step.pipeline_job.harvest_reports.exists?
    end
  end
end
