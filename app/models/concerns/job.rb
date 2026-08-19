# frozen_string_literal: true

module Job
  extend ActiveSupport::Concern

  STATUSES = %w[queued cancelled running completed errored].freeze

  # A job in one of these is over, however it got there. The rest are still to happen or
  # happening - which is not the same as "not finished": status is nullable, and a run created
  # before it is picked up has none at all.
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
