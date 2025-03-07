# frozen_string_literal: true

class AutomationStep < ApplicationRecord
  belongs_to :automation
  belongs_to :pipeline
  belongs_to :launched_by, class_name: 'User', optional: true
  has_one :pipeline_job, dependent: :destroy

  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  serialize :harvest_definition_ids, type: Array

  def harvest_definitions
    HarvestDefinition.where(id: harvest_definition_ids)
  end

  def display_name
    "#{position + 1}. #{pipeline.name}"
  end

  # Returns the status of this step
  # Prioritizes statuses in a logical order
  def status
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

  private

  def no_reports?
    pipeline_job&.harvest_reports.blank?
  end

  def report_statuses
    pipeline_job&.harvest_reports&.map(&:status)&.uniq || []
  end

  def status_from_statuses(statuses)
    return 'not_started' if not_started?(statuses)
    return 'cancelled' if cancelled?(statuses)
    return 'completed' if completed?(statuses)
    return 'errored' if errored?(statuses)
    return 'running' if running?(statuses)
    return 'queued' if queued?(statuses)

    'running' # Default fallback
  end

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
end
