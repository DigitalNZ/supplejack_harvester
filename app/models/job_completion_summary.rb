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

  private

  def find_pipeline_from_job(job_id, job_type)
    return nil unless job_id

    case job_type
    when 'PipelineJob'
      PipelineJob.find(job_id).pipeline
    when 'HarvestJob','TransformationJob'
      HarvestJob.find(job_id).pipeline_job.pipeline
    when 'ExtractionJob'
      extraction_job = ExtractionJob.find(job_id)
      # Try harvest_job first, then fall back to extraction_definition
      extraction_job.harvest_job&.pipeline_job&.pipeline ||
        extraction_job.extraction_definition.pipeline
    else
      nil
    end
  end
end
