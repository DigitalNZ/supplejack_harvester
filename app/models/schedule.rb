# frozen_string_literal: true

class Schedule < ApplicationRecord
  belongs_to :pipeline
  belongs_to :destination

  serialize :harvest_definitions_to_run, Array

  validates :name,                       presence: true, uniqueness: true
  validates :frequency,                  presence: true
  validates :time,                       presence: true
  validates :harvest_definitions_to_run, presence: true

  enum :frequency, { daily: 0, weekly: 1, fortnightly: 2, monthly: 3 }
  enum :day,       { sunday: 0, monday: 1, tuesday: 2, wednesday: 3, thursday: 4, friday: 5, saturday: 6 }, prefix: :on

  validates :day, presence: true,              if: -> { weekly? || fortnightly? }
  validates :day_of_the_month, presence: true, if: -> { monthly? }

  after_create :create_sidekiq_cron_job
  after_destroy :delete_sidekiq_cron_job

  def create_sidekiq_cron_job
    Sidekiq::Cron::Job.create(
      name:,
      cron: cron_syntax,
      class: 'ScheduleWorker',
      args: {
        pipeline_id: pipeline.id, harvest_definitions_to_run:,
        destination_id: destination.id, key: SecureRandom.hex,
        page_type: :all_available_pages
      }
    )
  end

  def delete_sidekiq_cron_job
    Sidekiq::Cron::Job.find(name).destroy
  end

  def cron_syntax
    "#{minute} #{hour} #{month_day} #{month} #{day_of_the_week}"
  end

  def sidekiq_cron_job
    Sidekiq::Cron::Job.find(sidekiq_cron_job_id)
  end

  private

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
    return '*' unless monthly?

    day_of_the_month
  end

  def month
    '*'
  end

  def hour_and_minutes
    time.split(':')
  end
end