# frozen_string_literal: true

module ApplicationHelper
  include ActiveSupport::NumberHelper

  # How much of a list its filters left: '40 of 331 pipelines match'. The collection knows
  # its own filtered total, but not the total it is a subset of, so that comes from the
  # caller. With nothing filtered out there is nothing to compare against, so it just
  # says how many there are.
  def list_summary(collection, total, noun)
    return "#{total} #{noun.pluralize(total)}" if collection.total_count == total

    "#{collection.total_count} of #{total} #{noun.pluralize(total)} match"
  end

  # Where a page sits in the list it came from: 'Showing 1-20 of 40 pipelines'. Counted
  # against the filtered total rather than everything there is, because the filtered list
  # is the one being paged through. An empty list has no page to describe.
  def page_summary(collection, noun)
    return if collection.total_count.zero?

    first = collection.offset_value + 1
    last = collection.offset_value + collection.length

    "Showing #{first}–#{last} of #{collection.total_count} #{noun.pluralize(collection.total_count)}"
  end

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
