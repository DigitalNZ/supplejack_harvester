# frozen_string_literal: true

module Job
  extend ActiveSupport::Concern

  STATUSES = %w[queued cancelled running completed errored].freeze

  # A job in one of these is over, however it got there. The rest are still to happen or are
  # happening - which is not quite the same as "not finished": the column is nullable, so a row
  # written before it had a default holds neither. A run created before its worker picks it up
  # reads queued, the same as a harvest job or an extraction job - pipeline_jobs.status was the
  # one of the three without a default until 20260818120000.
  FINISHED_STATUSES = %w[cancelled completed errored].freeze
  UNFINISHED_STATUSES = (STATUSES - FINISHED_STATUSES).freeze

  included do
    enum :status, STATUSES

    validates :status, presence: true, inclusion: { in: STATUSES }, if: -> { status.present? }
    validates :end_time, comparison: { greater_than_or_equal_to: :start_time }, if: -> { end_time.present? }
  end

  # Returns the number of seconds a job has been running for
  #
  # @return Integer
  def duration_seconds
    return if start_time.blank? || end_time.blank?

    end_time - start_time
  end

  # Returns true if a job is considered finished
  #
  # @return Boolean
  def finished?
    status.in? FINISHED_STATUSES
  end
end
