# frozen_string_literal: true

# Shared status-related functionality for models that need to compute a status from a collection of sub-statuses
module Status
  extend ActiveSupport::Concern

  def status_from_statuses(statuses)
    return 'not_started' if respond_to?(:not_started?, true) && not_started?(statuses)
    return 'cancelled' if respond_to?(:cancelled?, true) && cancelled?(statuses)
    return 'completed' if respond_to?(:completed?, true) && completed?(statuses)
    return 'errored' if respond_to?(:errored?, true) && errored?(statuses)
    return 'failed' if respond_to?(:failed?, true) && failed?(statuses)
    return 'running' if respond_to?(:running?, true) && running?(statuses)
    return 'queued' if respond_to?(:queued?, true) && queued?(statuses)

    'running'
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