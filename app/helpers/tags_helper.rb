# frozen_string_literal: true

module TagsHelper
  # The filters a list can already be under, which a tag filter has to leave alone.
  FILTER_PARAMS = %i[search format sort_by status destination run_by pipeline_id].freeze

  # The modifier that colours a tag, from the colour it carries.
  def tag_color_modifier(tag)
    "tag--#{tag.color.dasherize}"
  end

  # The classes a tag is drawn with, for the places that need the markup inside it: a
  # chip in the tag editor, or one of the tags a list is filtered by.
  def tag_classes(tag, css_class: nil)
    class_names('tag', tag_color_modifier(tag), css_class)
  end

  # A tag on its own: its colour as the text and the outline, so that a row of tags stays
  # quiet next to the status badges beside it (blocks/_tag.scss).
  def tag_label(tag, css_class: nil)
    content_tag :span, tag.name, class: tag_classes(tag, css_class:)
  end

  # The tags the editor offers as suggestions, as JSON for PipelineTags.js - the same
  # idea as the autocomplete_* helpers the definition pickers on this page use. Each
  # carries its modifier as well as its name, so a chip for a tag that already exists is
  # drawn in the colour that tag has rather than the grey a new one starts as.
  def autocomplete_tags
    Tag.ordered.map { |tag| { name: tag.name, modifier: tag_color_modifier(tag) } }.to_json
  end

  # The tags a list is being filtered by, as slugs.
  def tag_filter_slugs
    Array(params[:tags]).map(&:to_s).compact_blank.uniq
  end

  # A URL for this list filtered by a different set of tags. The other filters on the
  # page stay as they are, and no tags at all leaves the query out rather than sending
  # an empty one.
  def tag_filter_url(path, slugs)
    query = params.permit(*FILTER_PARAMS).to_h.merge('tags' => slugs).compact_blank

    query.empty? ? path : "#{path}?#{query.to_query}"
  end
end
