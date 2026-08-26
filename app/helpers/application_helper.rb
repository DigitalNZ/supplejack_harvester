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
end
