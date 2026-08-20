# frozen_string_literal: true

module TagsHelper
  # The filters a list can already be under, which a tag filter has to leave alone.
  FILTER_PARAMS = %i[search format sort_by status destination run_by pipeline_id].freeze

  # A tag as a hollow Bootstrap badge: an outline rather than a fill, so that a row of
  # tags stays quiet next to the status badges beside it.
  def tag_badge(tag, css_class: nil)
    content_tag :span, tag.name, class: class_names('badge', 'border', 'text-secondary', css_class)
  end

  # The names the editor offers as suggestions, as JSON for PipelineTags.js - the same
  # idea as the autocomplete_* helpers the definition pickers on this page use.
  def autocomplete_tags
    Tag.ordered.pluck(:name).to_json
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
