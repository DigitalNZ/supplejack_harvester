# frozen_string_literal: true

class ScheduleWorker
  include PerformWithPriority
  include Sidekiq::Job

  def perform(id)
    schedule = Schedule.find(id)

    if schedule.pipeline.present?
      begin
        job = create_pipeline_job(schedule)
        PipelineWorker.perform_async(job.id)
      rescue StandardError => e
        log_schedule_worker_error(e, schedule, 'pipeline_job_creation')
        raise
      end
    end

    return if schedule.automation_template.blank?

    begin
      AutomationTemplate.find(schedule.automation_template_id).run_automation
    rescue StandardError => e
      log_schedule_worker_error(e, schedule, 'automation_template_execution')
      raise
    end
  end

  private

  def create_pipeline_job(schedule)
    PipelineJob.create(
      pipeline_id: schedule.pipeline.id,
      harvest_definitions_to_run: schedule.harvest_definitions_to_run,
      destination_id: schedule.destination.id,
      key: SecureRandom.hex,
      page_type: :all_available_pages,
      schedule_id: schedule.id, delete_previous_records: schedule.delete_previous_records,
      job_priority: schedule.job_priority,
      skip_previously_enriched: schedule.skip_previously_enriched
    )
  end

  def log_schedule_worker_error(exception, schedule, error_context)
    extraction_id = "schedule_#{schedule.id}"
    extraction_name = "Schedule: #{schedule.name || 'Unnamed Schedule'}"

    JobCompletionSummary.log_error(
      extraction_id: extraction_id,
      extraction_name: extraction_name,
      message: "ScheduleWorker #{error_context} error: #{exception.class} - #{exception.message}",
      details: error_context
    )
  rescue StandardError => e
    Rails.logger.error "Failed to log ScheduleWorker error to JobCompletionSummary: #{e.message}"
    Rails.logger.error "Original error: #{exception.class} - #{exception.message}"
  end
end
