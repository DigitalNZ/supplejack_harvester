# frozen_string_literal: true

class ApplicationWorker
  include Sidekiq::Job

  sidekiq_options retry: 0

  def self.perform_async_with_priority(priority, *args)
    if priority.present?
      set(queue: priority).perform_async(*args)
    else
      perform_async(*args)
    end
  end

  def perform(*args)
    @job = find_job(args[0])
    @harvest_report = HarvestReport.find_by(id: args[1])

    job_start
    child_perform(@job, *args[2..])
    job_end
  end

  protected

  def find_job(job_id)
    job_class = self.class.name.gsub('Worker', 'Job').constantize
    job_class.find(job_id)
  end

  def job_start
    @job.running!
    @job.update(start_time: Time.zone.now) if @job.start_time.blank?
  end

  def job_end
    @job.completed! unless @job.cancelled?
    @job.update(end_time: Time.zone.now) if @job.end_time.blank?
  end
end
