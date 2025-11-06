# frozen_string_literal: true

class JobCompletion < ApplicationRecord
  enum completion_type: {
    error: 0,
    stop_condition: 1
  }

  enum process_type: {
    extraction: 0,
    transformation: 1
  }

  validates :source_id, uniqueness: { scope: %i[process_type job_type] }
  validates :source_name, presence: true

  validates :job_type, presence: true

  validates :stack_trace, presence: true
  validates :context, presence: true
  validates :message, presence: true
  validates :details, presence: true
  validates :completion_type, presence: true
  validates :process_type, presence: true

  scope :last_completed_at, -> { order(last_completed_at: :desc) }

  def stop_condition_name
    details&.dig('stop_condition_name')
  end

  def stop_condition_type
    details&.dig('stop_condition_type')
  end
end