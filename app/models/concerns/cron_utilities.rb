# frozen_string_literal: true

module CronUtilities
  extend ActiveSupport::Concern

  def create_sidekiq_cron_job
    Sidekiq::Cron::Job.create(name:, cron: cron_syntax, class: 'ScheduleWorker', args: id)
  end

  def delete_sidekiq_cron_job(sidekiq_cron_name = name)
    Sidekiq::Cron::Job.find(sidekiq_cron_name)&.destroy
  end

  def refresh_sidekiq_cron_job
    delete_sidekiq_cron_job(name_previously_was)
    create_sidekiq_cron_job
  end

  def cron_syntax
    "#{minute} #{hour} #{month_day} #{month} #{day_of_the_week}"
  end

  def next_run_time
    Fugit::Cron.parse(cron_syntax).next_time
  end

  def last_run_time
    pipeline_jobs.last.created_at
  end

  def hour
    hour_and_minutes.first
  end

  def minute
    return 0 if hour_and_minutes.count == 1

    hour_and_minutes.last
  end

  def day_of_the_week
    return '*' unless weekly?

    Schedule.days[day]
  end

  def month_day
    return '*' unless monthly? || bi_monthly?
    return "#{bi_monthly_day_one},#{bi_monthly_day_two}" if bi_monthly?

    day_of_the_month
  end

  def month
    '*'
  end

  def hour_and_minutes
    sanitized_time.split(':')
  end
end
