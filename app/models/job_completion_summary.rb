# frozen_string_literal: true

class JobCompletionSummary < ApplicationRecord
  enum process_type: {
    extraction: 0,
    transformation: 1
  }

  validates: job_completion_summary_id, presence: true
  validates :source_id, presence: true
  validates :source_name, presence: true
  validates :completion_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :job_type, presence: true

  validates :source_id, uniqueness: { scope: %i[process_type job_type] }

  has_many :job_completions, dependent: :destroy

  after_initialize :set_defaults, if: :new_record?

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
