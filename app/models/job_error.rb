# frozen_string_literal: true

class JobError < ApplicationRecord
  enum :process_type, {
    extraction: 0,
    transformation: 1
  }

  belongs_to :job_completion_summary

  validates :job_id, presence: true
  validates :job_type, presence: true
  validates :message, presence: true
  validates :process_type, presence: true
  validates :origin, presence: true
  validates :stack_trace, presence: true

  validate :stack_trace_must_be_array

  private

  def stack_trace_must_be_array
    return if stack_trace.is_a?(Array)

    errors.add(:stack_trace, 'must be an array')
  end
end
