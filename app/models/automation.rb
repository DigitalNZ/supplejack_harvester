# frozen_string_literal: true

class Automation < ApplicationRecord
  belongs_to :destination
  belongs_to :automation_template
  
  has_many :automation_steps, -> { order(position: :asc) }, dependent: :destroy
  
  validates :name, presence: true
  validates :destination, presence: { message: "must be selected" }
  
  def run
    # Get the first step in order
    first_step = automation_steps.order(position: :asc).first
    return if first_step.nil?
    
    # Queue the automation worker to handle the first step and subsequent steps
    AutomationWorker.perform_async(id, first_step.id)
  end
  
  def can_run?
    # Can only run if there are steps AND the automation is not already running/completed
    automation_steps.exists? && status == 'not_started'
  end
  
  def status
    step_statuses = automation_steps.map do |step|
      step.pipeline_job&.harvest_reports&.map(&:status)&.uniq
    end.flatten.compact

    return 'not_started' if step_statuses.empty? || step_statuses.all?('not_started')
    return 'running' if step_statuses.any?('running') || step_statuses.count != automation_steps.count
    return 'cancelled' if step_statuses.any?('cancelled')
    return 'completed' if step_statuses.all?('completed')
    return 'failed' if step_statuses.any?('errored')
    return 'queued' if step_statuses.any?('queued')
    
    'running'
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
    if harvest_definitions.blank?
      harvest_definitions = pipeline.harvest_definitions
    end
    
    # Generate a unique key for this pipeline job
    key = SecureRandom.hex(10)
    
    # Use the automation's destination
    destination_id = destination.id
    
    # Create the pipeline job
    pipeline_job = PipelineJob.create!(
      pipeline: pipeline,
      key: key,
      destination_id: destination_id,
      harvest_definitions_to_run: harvest_definitions.pluck(:id).map(&:to_s),
      launched_by_id: step.launched_by_id,
      automation_step: step
    )
    
    PipelineWorker.perform_async(pipeline_job.id)
    
    pipeline_job
  end
end 