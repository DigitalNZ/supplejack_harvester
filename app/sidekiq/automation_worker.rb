# frozen_string_literal: true

class AutomationWorker
  include Sidekiq::Job
  sidekiq_options retry: 5

  # Performs the automation step process
  # @param automation_id [Integer] The ID of the automation to process
  # @param step_id [Integer] The ID of the step to process
  def perform(automation_id, step_id)
    initialize_models(automation_id, step_id)
    process_step(automation_id, step_id)
  end

  private

  def initialize_models(automation_id, step_id)
    @automation = Automation.find(automation_id)
    @step = AutomationStep.find(step_id)
  end

  def process_step(automation_id, step_id)
    if step_completed?
      handle_next_step
      return
    end

    if step_has_job?
      schedule_job_check(automation_id, step_id)
      return
    end

    # Otherwise, create and start a new pipeline job for this step
    create_and_run_pipeline_job
    schedule_job_check(automation_id, step_id)
  end

  def step_completed?
    @step.pipeline_job.present? && all_reports_completed?
  end

  def all_reports_completed?
    @step.pipeline_job.harvest_reports.map(&:status).uniq.all?('completed')
  end

  def step_has_job?
    @step.pipeline_job.present?
  end

  def schedule_job_check(automation_id, step_id)
    # Check back in 30 seconds to see if the job has completed
    self.class.perform_in(30.seconds, automation_id, step_id)
  end

  def create_and_run_pipeline_job
    # Create a new pipeline job using the automation's create_pipeline_job method
    @automation.create_pipeline_job(@step)
  end

  def handle_next_step
    next_step = @step.next_step

    # If there's another step, queue a worker to handle it
    return if next_step.blank?

    self.class.perform_async(@automation.id, next_step.id)

    # Otherwise, the automation is complete
  end
end
