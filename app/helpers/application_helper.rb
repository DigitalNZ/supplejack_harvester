# frozen_string_literal: true

module ApplicationHelper
  include ActiveSupport::NumberHelper

  # The left-hand slot of the page header: what the page is about. It is a title, and under
  # it an optional line saying more - a string when that line is only words, or markup
  # passed as a block when it is more than words. The h1 and the muted line are written
  # once here rather than on every page, so no page can size its own title.
  #
  # A page whose title is not plain text - one edited in place - passes no title and builds
  # the whole heading in the block.
  def page_heading(title = nil, subtitle = nil, &block)
    content_for :heading do
      safe_join([
        (tag.h1(title) if title),
        (tag.p(subtitle, class: 'text-muted mb-0') if subtitle),
        (capture(&block) if block)
      ].compact)
    end
  end

  # The right-hand slot of the page header: what can be done to what the page shows. The
  # buttons are spaced by the header, so none of them carries a margin of its own.
  def page_actions(&)
    content_for(:actions) { capture(&) }
  end

  # The slot under both: the tabs of the thing the page is one page of.
  def page_tabs(&)
    content_for(:nav_tabs) { capture(&) }
  end

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
