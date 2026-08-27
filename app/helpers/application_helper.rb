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
        (tag.p(subtitle, class: 'text-body-secondary mb-0') if subtitle),
        (capture(&block) if block)
      ].compact)
    end
  end

  # The right-hand slot of the page header: what can be done to what the page shows. The
  # buttons are spaced by the header, so none of them carries a margin of its own.
  def page_actions(&)
    content_for(:actions) { capture(&) }
  end

  # The header of a page that is one form: what else can be done to what it shows, a way out
  # of it, and the button that submits it. Every such page wants the same three in the same
  # order, and had grown its own copy of them.
  #
  # The submit button sits in the header rather than at the foot of the form, and the form
  # attribute is what still makes it the form's - a plain button outside a form belongs to
  # no form at all. That association is what a browser needs to submit on Enter: a form with
  # no submit button of its own and more than one field in it does nothing when Enter is
  # pressed, which is every form on this pattern. Anything else the page can do goes in the
  # block, ahead of the way out.
  def form_page_actions(form_id:, submit_text: 'Update', cancel_path: nil, &extra)
    page_actions do
      safe_join([
        (capture(&extra) if extra),
        (link_to('Cancel', cancel_path, class: 'btn btn-outline-secondary') if cancel_path),
        tag.button(submit_text, type: 'submit', class: 'btn btn-primary', form: form_id)
      ].compact)
    end
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
end
