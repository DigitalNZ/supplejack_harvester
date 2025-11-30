# frozen_string_literal: true

class JobCompletionSummary < ApplicationRecord
  enum :process_type, {
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

    summary_ids = collect_summary_ids(harvest_job, harvest_job_id)
    return 0 if summary_ids.empty?

    JobError.where(job_completion_summary_id: summary_ids).count
  end

  def self.find_for_harvest_job(harvest_job_id)
    return nil if harvest_job_id.blank?

    harvest_job = HarvestJob.find_by(id: harvest_job_id)
    return nil unless harvest_job

    summaries = collect_summaries(harvest_job, harvest_job_id)
    return nil if summaries.empty?

    find_preferred_summary(summaries)
  end

  def self.collect_summary_ids(harvest_job, harvest_job_id)
    summary_ids = []
    if harvest_job.extraction_job_id.present?
      extraction_summaries = where(job_id: harvest_job.extraction_job_id, job_type: 'ExtractionJob')
      summary_ids += extraction_summaries.pluck(:id)
    end
    transformation_summaries = where(job_id: harvest_job_id, job_type: 'TransformationJob')
    summary_ids + transformation_summaries.pluck(:id)
  end

  def self.collect_summaries(harvest_job, harvest_job_id)
    summaries = []
    if harvest_job.extraction_job_id.present?
      extraction_summaries = where(job_id: harvest_job.extraction_job_id,
                                   job_type: 'ExtractionJob').includes(:job_errors)
      summaries += extraction_summaries.to_a
    end
    transformation_summaries = where(job_id: harvest_job_id, job_type: 'TransformationJob').includes(:job_errors)
    summaries + transformation_summaries.to_a
  end

  def self.find_preferred_summary(summaries)
    summary_with_errors = summaries.find { |s| s.job_errors.any? }
    summary_with_errors || summaries.first
  end

  private

  def find_pipeline_from_job(job_id, job_type)
    return nil unless job_id

    case job_type
    when 'PipelineJob'
      find_pipeline_from_pipeline_job(job_id)
    when 'HarvestJob', 'TransformationJob'
      find_pipeline_from_harvest_job(job_id)
    when 'ExtractionJob'
      find_pipeline_from_extraction_job(job_id)
    end
  end

  def find_pipeline_from_pipeline_job(job_id)
    PipelineJob.find(job_id).pipeline
  end

  def find_pipeline_from_harvest_job(job_id)
    HarvestJob.find(job_id).pipeline_job.pipeline
  end

  def find_pipeline_from_extraction_job(job_id)
    extraction_job = ExtractionJob.find_by(id: job_id)
    # if job is deleted, handle safely
    return nil unless extraction_job
    
    extraction_job.harvest_job&.pipeline_job&.pipeline ||
      extraction_job.extraction_definition.pipeline
  end
end
