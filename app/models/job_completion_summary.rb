# frozen_string_literal: true

class JobCompletionSummary < ApplicationRecord
  enum process_type: {
    extraction: 0,
    transformation: 1
  }

  validates :job_id, presence: true
  validates :job_type, presence: true

  has_many :job_completions, dependent: :destroy
  has_many :job_errors, dependent: :destroy

  def pipeline_name
    pipeline = find_pipeline_from_job(job_id, job_type)
    pipeline&.name
  end

  def definition_name
    harvest_definition = HarvestDefinition.find_by(job_id: job_id)

    case process_type
    when 'extraction'
      harvest_definition&.extraction_definition&.name
    when 'transformation'
      harvest_definition&.transformation_definition&.name
    else
      'Unknown Type'
    end
  end

  def last_completed_at
    job_completions.order(updated_at: :desc).first&.updated_at
  end

  def completion_count
    job_completions.count + job_errors.count
  end

  def all_records
    (job_completions.to_a + job_errors.to_a).sort_by { |r| r.updated_at || r.created_at }.reverse
  end

  def error_count
    job_errors.count
  end

  def self.error_count_for_harvest_job(harvest_job_id)
    return 0 if harvest_job_id.blank?

    harvest_job = HarvestJob.find_by(id: harvest_job_id)
    return 0 unless harvest_job

    # Find summaries for extraction (if extraction_job exists) and transformation
    summary_ids = []

    # Check for extraction summaries
    if harvest_job.extraction_job_id.present?
      extraction_summaries = where(job_id: harvest_job.extraction_job_id, job_type: 'ExtractionJob')
      summary_ids += extraction_summaries.pluck(:id)
    end

    # Check for transformation summaries (using harvest_job_id)
    transformation_summaries = where(job_id: harvest_job_id, job_type: 'TransformationJob')
    summary_ids += transformation_summaries.pluck(:id)

    return 0 if summary_ids.empty?

    JobError.where(job_completion_summary_id: summary_ids).count
  end

  def self.find_for_harvest_job(harvest_job_id)
    return nil if harvest_job_id.blank?

    harvest_job = HarvestJob.find_by(id: harvest_job_id)
    return nil unless harvest_job

    summaries = []

    # Check for extraction summaries
    if harvest_job.extraction_job_id.present?
      extraction_summaries = where(job_id: harvest_job.extraction_job_id,
                                   job_type: 'ExtractionJob').includes(:job_errors)
      summaries += extraction_summaries.to_a
    end

    # Check for transformation summaries
    transformation_summaries = where(job_id: harvest_job_id, job_type: 'TransformationJob').includes(:job_errors)
    summaries += transformation_summaries.to_a

    return nil if summaries.empty?

    # Prefer a summary with errors, otherwise return the first one found
    summary_with_errors = summaries.find { |s| s.job_errors.any? }
    summary_with_errors || summaries.first
  end

  private

  def find_pipeline_from_job(job_id, job_type)
    return nil unless job_id

    case job_type
    when 'PipelineJob'
      PipelineJob.find(job_id).pipeline
    when 'HarvestJob', 'TransformationJob'
      HarvestJob.find(job_id).pipeline_job.pipeline
    when 'ExtractionJob'
      extraction_job = ExtractionJob.find(job_id)
      # Try harvest_job first, then fall back to extraction_definition
      extraction_job.harvest_job&.pipeline_job&.pipeline ||
        extraction_job.extraction_definition.pipeline
    end
  end
end
