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

  def status
    return 'not_started' if pipeline_job&.harvest_reports.blank?

    statuses = pipeline_job&.harvest_reports&.map(&:status)&.uniq

    return 'not_started' if statuses.blank? || statuses.include?('not_started')
    return 'cancelled' if statuses.include?('cancelled')
    return 'completed' if statuses.all?('completed')
    return 'errored' if statuses.include?('errored')
    return 'running' if statuses.include?('running')
    return 'queued' if statuses.include?('queued')

    'running'
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
end
