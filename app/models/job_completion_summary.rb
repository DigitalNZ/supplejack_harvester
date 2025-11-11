# frozen_string_literal: true

class JobCompletionSummary < ApplicationRecord
  enum completion_type: {
    error: 0,
    stop_condition: 1
  }

  enum process_type: {
    extraction: 0,
    transformation: 1
  }

  validates :source_id, presence: true
  validates :source_name, presence: true
  validates :completion_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :job_type, presence: true

  validates :source_id, uniqueness: { scope: %i[process_type job_type] }

  after_initialize :set_defaults, if: :new_record?

  scope :by_completion_type, ->(type) { where(completion_type: type) }

  def pipeline_name
    harvest_definition = HarvestDefinition.find_by(source_id: source_id)
    harvest_definition&.pipeline&.name
  end

  def definition_name
    harvest_definition = HarvestDefinition.find_by(source_id: source_id)

    case process_type
    when 'extraction'
      harvest_definition&.extraction_definition&.name
    when 'transformation'
      harvest_definition&.transformation_definition&.name
    else
      'Unknown Type'
    end
  end

  def job_completions
    JobCompletion.where(source_id: source_id, process_type: process_type, job_type: job_type)
  end

  def last_completed_at
    job_completions.order(updated_at: :desc).first&.updated_at
  end

  def increment_completion_count
    update(completion_count: completion_count + 1)
  end

  private

  def set_defaults
    self.completion_count ||= 0
  end
end
