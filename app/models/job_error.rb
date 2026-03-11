# frozen_string_literal: true

class JobError < ApplicationRecord
  enum :process_type, {
    extraction: 0,
    transformation: 1
  }

  LOAD_STAGE_ORIGINS = %w[LoadWorker DeleteWorker].freeze

  belongs_to :job_completion_summary

  scope :for_extraction_job, ->(job_id) { where(job_id:, job_type: 'ExtractionJob') }
  scope :for_transformation_job, ->(job_id) { where(job_id:, job_type: 'TransformationJob') }
  scope :recent_first, -> { order(updated_at: :desc, created_at: :desc) }

  validates :job_id, presence: true
  validates :job_type, presence: true
  validates :message, presence: true
  validates :process_type, presence: true
  validates :origin, presence: true
  validates :stack_trace, presence: true

  validate :stack_trace_must_be_array

  def self.count_for_harvest_job(harvest_job)
    return 0 if harvest_job.blank?

    extraction_job_id = harvest_job.extraction_job_id
    extraction_error_count = if extraction_job_id.present?
                               for_extraction_job(extraction_job_id).count
                             else
                               0
                             end

    extraction_error_count + for_transformation_job(harvest_job.id).count
  end

  def self.grouped_for_harvest_job(harvest_job)
    return empty_stage_groups if harvest_job.blank?

    extraction_stage_errors, load_errors = partition_extraction_stage_errors(harvest_job)

    {
      extraction: extraction_stage_errors,
      transformation: transformation_errors_for(harvest_job),
      load: load_errors
    }
  end

  class << self
    private

    def extraction_errors_for(harvest_job)
      extraction_job_id = harvest_job.extraction_job_id
      return [] if extraction_job_id.blank?

      for_extraction_job(extraction_job_id).recent_first.to_a
    end

    def partition_extraction_stage_errors(harvest_job)
      load_errors, extraction_errors = extraction_errors_for(harvest_job).partition do |error|
        LOAD_STAGE_ORIGINS.include?(error.origin)
      end

      [extraction_errors, load_errors]
    end

    def transformation_errors_for(harvest_job)
      for_transformation_job(harvest_job.id).recent_first.to_a
    end

    def empty_stage_groups
      { extraction: [], transformation: [], load: [] }
    end
  end

  private

  def stack_trace_must_be_array
    return if stack_trace.is_a?(Array)

    errors.add(:stack_trace, 'must be an array')
  end
end
