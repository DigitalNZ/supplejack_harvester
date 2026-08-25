# frozen_string_literal: true

module ApplicationHelper
  include ActiveSupport::NumberHelper

  # How much of a list its filters left: '40 of 331 pipelines match'. The collection knows
  # its own filtered total, but not the total it is a subset of, so that comes from the
  # caller. With nothing filtered out there is nothing to compare against, so it just
  # says how many there are.
  def list_summary(collection, total, noun)
    left = collection.total_count
    nouns = noun.pluralize(total)

    left == total ? "#{total} #{nouns}" : "#{left} of #{total} #{nouns} match"
  end

  # Where a page sits in the list it came from: 'Showing 1-20 of 40 pipelines'. Counted
  # against the filtered total rather than everything there is, because the filtered list
  # is the one being paged through. An empty list has no page to describe.
  def page_summary(collection, noun)
    total = collection.total_count
    return if total.zero?

    offset = collection.offset_value

    "Showing #{offset + 1}–#{offset + collection.length} of #{total} #{noun.pluralize(total)}"
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
