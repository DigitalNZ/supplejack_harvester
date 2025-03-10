# frozen_string_literal: true

class CheckPipelineJobCompletionWorker
  include Sidekiq::Job
  sidekiq_options retry: 5

  def perform(pipeline_job_id)
    pipeline_job = PipelineJob.find_by(id: pipeline_job_id)
    return if pipeline_job.nil?

    # Check if the job has a harvest report and it's completed
    if pipeline_job.harvest_report&.completed?
      # If this job is part of an automation, trigger the next step
      pipeline_job.trigger_next_automation_step if pipeline_job.from_automation?
    else
      # If the job is still running, check back in 30 seconds
      self.class.perform_in(30.seconds, pipeline_job_id)
    end
  end
end
