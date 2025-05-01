# frozen_string_literal: true

class AutomationWorker
  include PerformWithPriority
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
    case @step.step_type
    when 'api_call'
      process_api_call_step(automation_id, step_id)
    else
      process_pipeline_step(automation_id, step_id)
    end
  end

  def process_api_call_step(automation_id, step_id)
    if step_api_call_completed?
      handle_next_step
      return
    end

    return if @step.api_response_report.present? && @step.api_response_report.failed?

    handle_queued_or_new_api_call(automation_id, step_id)
  end

  def handle_queued_or_new_api_call(automation_id, step_id)
    if @step.api_response_report.present? && @step.api_response_report.queued?
      schedule_job_check(automation_id, step_id)
      return
    end

    @step.execute_api_call
    schedule_job_check(automation_id, step_id)
  end

  def step_api_call_completed?
    @step.api_response_report.present? && @step.api_response_report.successful?
  end

  def process_pipeline_step(automation_id, step_id)
    if step_pipeline_completed?
      handle_next_step
      return
    end

    if step_has_pipeline_job?
      schedule_job_check(automation_id, step_id)
      return
    end

    # Otherwise, create and start a new pipeline job for this step
    create_and_run_pipeline_job
    schedule_job_check(automation_id, step_id)
  end

  def step_pipeline_completed?
    @step.pipeline_job.present? && all_reports_completed?
  end

  def all_reports_completed?
    @step.pipeline_job.harvest_reports.map(&:status).uniq.all?('completed')
  end

  def step_has_pipeline_job?
    @step.pipeline_job.present?
  end

  def schedule_job_check(automation_id, step_id)
    @step.pipeline_job&.pipeline&.complete_finished_jobs!
    # Check back in 30 seconds to see if the job has completed
    self.class.perform_in_with_priority(@automation.automation_template.job_priority, 30.seconds, automation_id, step_id)
  end

  def create_and_run_pipeline_job
    # Create a new pipeline job using the automation's create_pipeline_job method
    @automation.create_pipeline_job(@step)
  end

  def handle_next_step
    next_step = @step.next_step

    # If there's another step, queue a worker to handle it
    return if next_step.blank?

    self.class.perform_async_with_priority(@automation.automation_template.job_priority, @automation.id, next_step.id)

    # Otherwise, the automation is complete
  end
end
