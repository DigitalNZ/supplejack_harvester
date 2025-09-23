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
        log_schedule_error(e, schedule, 'pipeline_job_creation')
        raise
      end
    end

    return if schedule.automation_template.blank?

    begin
      AutomationTemplate.find(schedule.automation_template_id).run_automation
    rescue StandardError => e
      log_schedule_error(e, schedule, 'automation_template_execution')
      raise
    end
  end

  private

  def log_schedule_error(error, schedule, error_context)
    extraction_info = Supplejack::JobCompletionSummaryLogger.extract_from_schedule(schedule)
    
    Supplejack::JobCompletionSummaryLogger.log_completion(
      worker_class: 'ScheduleWorker',
      exception: error,
      extraction_id: extraction_info[:extraction_id],
      extraction_name: extraction_info[:extraction_name],
      message: "ScheduleWorker #{error_context} error: #{error.class} - #{error.message}",
      details: {
        schedule_id: schedule.id,
        schedule_name: schedule.name,
        error_context: error_context
      }
    )
  end

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
