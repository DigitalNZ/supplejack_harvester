# frozen_string_literal: true

class ScheduleWorker
  include PerformWithPriority
  include Sidekiq::Job

  def perform(id)
    schedule = Schedule.find(id)

    if schedule.pipeline.present?
      job = create_pipeline_job(schedule)
      PipelineWorker.perform_async(job.id)
    end

    return if schedule.automation_template.blank?

    AutomationTemplate.find(schedule.automation_template_id).run_automation
  end

  private

  def create_pipeline_job(schedule)
    PipelineJob.create(
      pipeline_id: schedule.pipeline.id, destination_id: schedule.destination.id,
      schedule_id: schedule.id, page_type: :all_available_pages,
      harvest_definitions_to_run: schedule.harvest_definitions_to_run,
      block_settings: schedule.block_settings, job_priority: schedule.job_priority,
      delete_previous_records: schedule.delete_previous_records,
      skip_previously_enriched: schedule.skip_previously_enriched,
      run_enrichment_concurrently: schedule.run_enrichment_concurrently
    )
  end
end
