# frozen_string_literal: true

class Schedule < ApplicationRecord
  include CronUtilities

  belongs_to :pipeline, optional: true
  belongs_to :automation_template, optional: true
  belongs_to :destination
  has_many   :pipeline_jobs, dependent: :nullify

  serialize :harvest_definitions_to_run, type: Array

  validates :frequency,                  presence: true
  validates :time,                       presence: true
  validate :time_format

  enum :frequency, { daily: 0, weekly: 1, bi_monthly: 2, monthly: 3 }
  enum :day,       { sunday: 0, monday: 1, tuesday: 2, wednesday: 3, thursday: 4, friday: 5, saturday: 6 }, prefix: :on

  validates :day, presence: true, if: -> { weekly? }
  validates :harvest_definitions_to_run, presence: true, if: -> { pipeline.present? }

  with_options presence: true, if: :bi_monthly? do
    validates :bi_monthly_day_one
    validates :bi_monthly_day_two
  end

  validates :day_of_the_month, presence: true, if: -> { monthly? }

  validate :scheduled_resource_present

  def time_format
    return if time.blank?

    begin
      parsed_time = Time.zone.parse(time)
      errors.add(:time, 'must be a valid time') if parsed_time.blank?
    rescue StandardError
      errors.add(:time, 'must be a valid time')
    end
  end

  after_create do
    self.name = schedule_name
    save!
  end

  def self.schedules_within_range(start_date, end_date)
    schedule_map = Schedule.all.each_with_object({}) do |schedule, hash|
      add_schedule_times_to_schedule_map(schedule, hash, start_date, end_date)
    end

    schedule_map.sort.to_h.transform_values! do |times|
      times.sort.to_h
    end
  end

  def self.add_schedule_times_to_schedule_map(schedule, schedule_map, start_date, end_date)
    enumerate_occurences(schedule, start_date, end_date).each do |time|
      date = time.to_date
      time_str = time.strftime('%H%M').to_i

      schedule_map[date] ||= {}
      schedule_map[date][time_str] ||= []
      schedule_map[date][time_str] << schedule
    end
  end

  def self.enumerate_occurences(schedule, start_date, end_date)
    Fugit.parse(schedule.cron_syntax)
         .within(start_date...end_date)
         .map { |eo| eo.to_t.in_time_zone(Time.zone) }
  end

  def scheduled_resource_present
    return unless pipeline.blank? && automation_template.blank?

    errors.add(:base, 'Either a pipeline or an automation template must be associated with this schedule')
  end

  def subject
    pipeline.presence || automation_template
  end

  private

  def schedule_name
    name = subject.name.parameterize(separator: '_')
    destination_name = destination.name.parameterize(separator: '_')
    time_name = time.parameterize(separator: '_')

    "#{name}__#{destination_name}__#{time_name}__#{SecureRandom.hex}"
  end

  # This is for converting 12 hour times into 24 hour times
  # so if the user has a time of 7:45pm, it becomes 19:45
  def sanitized_time
    time_lower = time.downcase
    return Time.zone.parse(time).strftime('%H:%M') if time_lower.include?('am') || time_lower.include?('pm')

    time
  end
end
