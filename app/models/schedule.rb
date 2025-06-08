# frozen_string_literal: true

class Schedule < ApplicationRecord
  belongs_to :pipeline, optional: true
  belongs_to :automation_template, optional: true
  belongs_to :destination
  has_many   :pipeline_jobs, dependent: :nullify

  serialize :harvest_definitions_to_run, type: Array

  validates :frequency,                  presence: true
  validates :time,                       presence: true
  validates :harvest_definitions_to_run, presence: true

  enum :frequency, { daily: 0, weekly: 1, bi_monthly: 2, monthly: 3 }
  enum :day,       { sunday: 0, monday: 1, tuesday: 2, wednesday: 3, thursday: 4, friday: 5, saturday: 6 }, prefix: :on

  validates :day, presence: true, if: -> { weekly? }

  with_options presence: true, if: :bi_monthly? do
    validates :bi_monthly_day_one
    validates :bi_monthly_day_two
  end

  after_create do
    self.name = "#{pipeline.name.parameterize(separator: '_')}__#{destination.name.parameterize(separator: '_')}__#{time.parameterize(separator: '_')}__#{SecureRandom.hex}"
    save!
  end

  validates :day_of_the_month, presence: true, if: -> { monthly? }

  validate :scheduled_resource_present

  def self.schedules_within_range(start_date, end_date)
    schedule_map = {}
  
    Schedule.all.each do |schedule|
      times = Fugit.parse(schedule.cron_syntax).within((start_date...end_date))
      
      times.each do |time|
        date = time.to_t.to_date
        time_str = time.strftime('%H%M').to_i
        
        schedule_map[date] ||= {}
        schedule_map[date][time_str] ||= []
        schedule_map[date][time_str] << schedule
      end
    end

    schedule_map = schedule_map.sort.to_h
    schedule_map.transform_values! do |times|
      times.sort.to_h
    end

    schedule_map
  end

  def scheduled_resource_present
    if pipeline.blank? && automation_template.blank?
      errors.add(:base, 'Either a pipeline or an automation template must be associated with this schedule')
    end
  end

  def create_sidekiq_cron_job
    Sidekiq::Cron::Job.create(
      name:,
      cron: cron_syntax,
      class: 'ScheduleWorker',
      args: id
    )
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

  # This is for converting 12 hour times into 24 hour times
  # so if the user has a time of 7:45pm, it becomes 19:45
  def sanitized_time
    return DateTime.parse(time).strftime('%H:%M') if time.downcase.include?('am') || time.downcase.include?('pm')

    time
  end
end
