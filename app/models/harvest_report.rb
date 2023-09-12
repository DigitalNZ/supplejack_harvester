# frozen_string_literal: true

class HarvestReport < ApplicationRecord
  belongs_to :pipeline_job
  belongs_to :harvest_job

  STATUSES = %w[queued cancelled running completed errored].freeze

  enum :extraction_status,     STATUSES, prefix: :extraction
  enum :transformation_status, STATUSES, prefix: :transformation
  enum :load_status,           STATUSES, prefix: :load
  enum :delete_status,         STATUSES, prefix: :delete

  delegate :harvest_definition, to: :harvest_job
  delegate :extraction_definition, to: :harvest_job
  delegate :transformation_definition, to: :harvest_job

  enum :kind, { harvest: 0, enrichment: 1 }

  METRICS = %w[
    pages_extracted
    records_transformed
    records_loaded
    records_rejected
    records_deleted
    transformation_workers_queued
    transformation_workers_completed
    load_workers_queued
    load_workers_completed
    delete_workers_queued
    delete_workers_completed
  ].freeze

  TIME_METRICS = %i[
    extraction_start_time
    extraction_updated_time
    extraction_end_time
    transformation_start_time
    transformation_updated_time
    transformation_end_time
    load_start_time
    load_updated_time
    load_end_time
    delete_start_time
    delete_updated_time
    delete_end_time
  ].freeze

  def complete?
    reload
    extraction_completed? && transformation_completed? && load_completed? && delete_completed?
  end

  %i[extraction transformation load delete].each do |process|
    define_method("#{process}_running!") do
      super()
      send(:update, "#{process}_start_time" => Time.zone.now)
    end

    define_method("#{process}_completed!") do
      super()
      send(:update, "#{process}_end_time" => Time.zone.now)
    end
  end

  ## These queries are all done atomically on the database
  # To prevent race conditions when multiple sidekiq processes are updating the same report at the same time.
  METRICS.each do |metric|
    define_method("increment_#{metric}!") do |amount = 1|
      # rubocop:disable Rails/SkipsModelValidations
      HarvestReport.where(id:).update_all("#{metric} = #{metric} + #{amount}")
      # rubocop:enable Rails/SkipsModelValidations
    end
  end

  def duration_seconds
    return nil if times.empty?

    min = times.min
    max = times.max

    ((max - min) - idle_offset).to_i
  end

  def status
    return 'cancelled' if pipeline_job.cancelled?
    return 'queued'    if statuses.all?('queued')
    return 'running'   if statuses.any?('running')
    return 'running'   if statuses.any?('completed') && statuses.any?('queued')
    return 'completed' if statuses.all?('completed')
  end

  def transformation_workers_completed?
    reload
    extraction_completed? && transformation_workers_queued == transformation_workers_completed
  end

  def load_workers_completed?
    reload
    transformation_completed? && load_workers_queued == load_workers_completed
  end

  def delete_workers_completed?
    reload
    transformation_completed? && delete_workers_queued == delete_workers_completed
  end

  private

  def times
    TIME_METRICS.filter_map { |time| send(time) }
  end

  def statuses
    [extraction_status, transformation_status, load_status, delete_status]
  end

  def idle_offset
    return 0 if extraction_end_time.blank?
    return @idle_offset if @idle_offset.present?

    @idle_offset = transformation_start_time - extraction_end_time
    @idle_offset = 0 if @idle_offset.negative?
    @idle_offset
  end
end
