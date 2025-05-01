# frozen_string_literal: true

class Automation < ApplicationRecord
  include StatusManagement

  belongs_to :destination
  belongs_to :automation_template

  has_many :automation_steps, -> { order(position: :asc) },
           dependent: :destroy,
           inverse_of: :automation

  validates :name, presence: true
  validates :destination, presence: { message: I18n.t('automation.validations.destination') }

  def run
    # Get the first step in order
    first_step = automation_steps.order(position: :asc).first
    return if first_step.nil?

    # Queue the automation worker to handle the first step and subsequent steps
    AutomationWorker.perform_async_with_priority(automation_template.job_priority, id, first_step.id)
  end

  def can_run?
    # Can only run if there are steps AND the automation is not already running/completed
    automation_steps.exists? && status == 'not_started'
  end

  def status
    statuses = collect_step_statuses
    status_from_statuses(statuses)
  end

  def total_harvest_definitions
    automation_steps.sum do |step|
      step.harvest_definitions.length
    end
  end

  def create_pipeline_job(step)
    pipeline = step.pipeline
    harvest_definitions = step.harvest_definitions

    # If no harvest definition IDs are selected, use all of them
    harvest_definitions = pipeline.harvest_definitions if harvest_definitions.blank?

    create_job_with_definitions(step, pipeline, harvest_definitions)
  end

  private

  def create_job_with_definitions(step, pipeline, harvest_definitions)
    # Generate a unique key for this pipeline job
    key = SecureRandom.hex(10)

    # Create the pipeline job
    pipeline_job = build_pipeline_job(step, pipeline, key, harvest_definitions)

    # Queue the job
    queue_pipeline_job(pipeline_job)

    pipeline_job
  end

  def build_pipeline_job(step, pipeline, key, harvest_definitions)
    PipelineJob.create!(
      pipeline:,
      key:,
      destination_id: destination.id,
      harvest_definitions_to_run: harvest_definitions.pluck(:id).map(&:to_s),
      launched_by_id: step.launched_by_id,
      automation_step: step,
      job_priority: automation_template.job_priority
    )
  end

  def queue_pipeline_job(pipeline_job)
    PipelineWorker.perform_async_with_priority(pipeline_job.job_priority, pipeline_job.id)
  end

  def collect_step_statuses
    automation_steps.map do |step|
      collect_status_for_step(step)
    end.flatten.compact
  end

  def collect_status_for_step(step)
    if step.step_type == 'api_call'
      collect_api_call_status(step)
    else
      collect_pipeline_status(step)
    end
  end

  def collect_api_call_status(step)
    step.api_response_report&.status
  end

  def collect_pipeline_status(step)
    return unless step.pipeline_job

    reports = step.pipeline_job.harvest_reports
    reports&.map(&:status)&.uniq
  end

  def not_started?(statuses)
    # An automation is not started if there are no statuses
    # or if all reported statuses are 'not_started'
    statuses.empty? || (statuses.all?('not_started') && automation_steps.count == statuses.count)
  end

  def running?(statuses)
    # An automation is running if any status is 'running'
    # or if not all steps have reported their status yet
    statuses.any?('running') || !automation_steps.all? do |step|
      step_has_report?(step)
    end
  end

  def cancelled?(statuses)
    statuses.any?('cancelled')
  end

  def completed?(statuses)
    # First check if all steps have reports
    all_steps_have_reports = automation_steps.all? do |step|
      step_has_report?(step)
    end

    # Then verify all reported statuses are 'completed'
    all_steps_have_reports && statuses.all?('completed')
  end

  def failed?(statuses)
    statuses.any?('errored')
  end

  def queued?(statuses)
    statuses.any?('queued')
  end
end
