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
      rescue StandardError => error
        Supplejack::JobCompletionSummaryLogger.log_schedule_worker_completion(
          exception: error,
          schedule: schedule,
          error_context: 'pipeline_job_creation'
        )
        raise
      end
    end

    return if schedule.automation_template.blank?

    begin
      AutomationTemplate.find(schedule.automation_template_id).run_automation
    rescue StandardError => error
      Supplejack::JobCompletionSummaryLogger.log_schedule_worker_completion(
        exception: error,
        schedule: schedule,
        error_context: 'automation_template_execution'
      )
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

end
