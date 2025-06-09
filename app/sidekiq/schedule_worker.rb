# frozen_string_literal: true

class ScheduleWorker
  include PerformWithPriority
  include Sidekiq::Job

  def perform(id)
    schedule = Schedule.find(id)

    if schedule.pipeline.present?

      job = PipelineJob.create(
        pipeline_id: schedule.pipeline.id,
        harvest_definitions_to_run: schedule.harvest_definitions_to_run,
        destination_id: schedule.destination.id,
        key: SecureRandom.hex,
        page_type: :all_available_pages,
        schedule_id: id, delete_previous_records: schedule.delete_previous_records
      )

      PipelineWorker.perform_async(job.id)
    end

    if schedule.automation_template.present?
      AutomationTemplate.find(schedule.automation_template_id).run_automation
    end
  end
end
