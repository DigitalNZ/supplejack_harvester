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
