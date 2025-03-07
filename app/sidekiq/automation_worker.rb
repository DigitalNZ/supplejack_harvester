# frozen_string_literal: true

class AutomationWorker
  include Sidekiq::Job
  sidekiq_options retry: 5

  # Performs the automation step process
  # @param automation_id [Integer] The ID of the automation to process
  # @param step_id [Integer] The ID of the step to process
  def perform(automation_id, step_id)
    @automation = Automation.find(automation_id)
    @step = AutomationStep.find(step_id)

    # If the step already has a harvest report that's completed, check if we need to move to the next step
    if @step.pipeline_job.present? && @step.pipeline_job.harvest_reports.map(&:status).uniq.all?('completed')
      handle_next_step
      return
    end

    # If the step already has a harvest report (regardless of status),
    # we'll schedule a check later - don't create a new one
    if @step.pipeline_job.present?
      # Check back in 30 seconds to see if the job has completed
      self.class.perform_in(30.seconds, automation_id, step_id)
      return
    end

    # Otherwise, create and start a new pipeline job for this step
    create_and_run_pipeline_job

    # Schedule a check to see if the job has completed
    self.class.perform_in(30.seconds, automation_id, step_id)
  end

  private

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
