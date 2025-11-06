# frozen_string_literal: true

module ApplicationHelper
  include ActiveSupport::NumberHelper

  def last_edited_by(resource)
    return if resource&.last_edited_by.nil?

    "Last edited by #{resource.last_edited_by.username}"
  end

  # Map of status to CSS class names
  STATUS_CLASS_MAPPING = {
    'completed' => 'status-completed',
    'running' => 'status-running',
    'errored' => 'status-errored',
    'queued' => 'status-queued'
  }.freeze

  # Returns the appropriate CSS class based on step status
  def step_status_class(status)
    STATUS_CLASS_MAPPING[status] || 'status-not_started'
  end

  # Map of status to Bootstrap badge classes
  BADGE_CLASS_MAPPING = {
    'completed' => 'bg-success',
    'failed' => 'bg-danger',
    'running' => 'bg-primary',
    'queued' => 'bg-warning',
    'not_started' => 'bg-secondary'
  }.freeze

  # Returns the appropriate Bootstrap badge class based on automation status
  def status_badge_class(status)
    BADGE_CLASS_MAPPING[status] || 'bg-secondary'
  end
end
