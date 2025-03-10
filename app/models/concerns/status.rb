# frozen_string_literal: true

# Shared status-related functionality for models that need to compute a status from a collection of sub-statuses
module Status
  extend ActiveSupport::Concern

  # Status check in priority order - first match wins
  STATUS_PRIORITY = {
    'not_started' => :not_started?,
    'cancelled' => :cancelled?,
    'completed' => :completed?,
    'errored' => :errored?,
    'failed' => :failed?,
    'running' => :running?,
    'queued' => :queued?
  }.freeze

  def status_from_statuses(statuses)
    STATUS_PRIORITY.each do |status, method_name|
      return status if can_check_status?(method_name) && send(method_name, statuses)
    end

    'running' # Default status if no conditions match
  end

  private

  def can_check_status?(method_name)
    respond_to?(method_name, true)
  end

  # No default implementations for status check methods
  # Each including class must define their own implementations for:
  # - not_started?(statuses)
  # - cancelled?(statuses)
  # - completed?(statuses)
  # - errored?(statuses) and/or failed?(statuses)
  # - running?(statuses)
  # - queued?(statuses)
end
