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

  validates :job_type, presence: true

  validates :source_id, uniqueness: { scope: %i[process_type job_type] }

  validates :completion_entries, presence: true
  validates :completion_count, presence: true, numericality: { greater_than_or_equal_to: 0 }

  after_initialize :set_defaults, if: :new_record?

  scope :recent_completions, -> { order(last_completed_at: :desc) }

  def self.log_completion(params)
    entry_params = if params[:completion_type] == :stop_condition
                     JobCompletion::CompletionDetailsBuilder.stop_condition_details(params)
                   else
                     JobCompletion::CompletionDetailsBuilder.error_details(params)
                   end

    JobCompletion::CompletionSummaryBuilder.build_completion_summary(entry_params)
  end

  def completion_types_present
    completion_entries.map do |entry|
      if entry['details']&.dig('stop_condition_name').present?
        'stop_condition'
      else
        'error'
      end
    end.uniq
  end

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

  private

  def set_defaults
    self.completion_entries ||= []
    self.completion_count ||= 0
  end
end
