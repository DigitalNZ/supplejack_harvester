# frozen_string_literal: true

class PipelineSearchQuery
  def initialize(params)
    @words = sanitized_words(params[:search])
    @format = params[:format]
    @tags = params[:tags]
    @query = Pipeline.includes(%i[last_edited_by schedules tags])
  end

  def call
    tagged(searched)
  end

  private

  # The tag filter narrows whatever the search and format left, and has to be applied
  # after them rather than before: the search ORs its terms together, and a tag folded
  # into that would widen the results instead of narrowing them.
  def tagged(query)
    return query if @tags.blank?

    query.tagged_with_all(@tags)
  end

  def searched
    return @query if @words.blank? && @format.blank?
    return @query.where(id: search_format_ids) if @words.blank? && @format.present?

    @query = or_words_filters
    @query = and_format_filter if @format.present?

    @query
  end

  def sanitized_words(words)
    words = Pipeline.sanitize_sql_like(words || '')
    return nil if words.empty?

    "%#{words}%"
  end

  def or_words_filters
    @query.where('name LIKE ?', @words)
          .or(Pipeline.where('description LIKE ?', @words))
          .or(Pipeline.where(last_edited_by_id: search_user_ids))
          .or(Pipeline.where(id: search_source_ids))
  end

  def and_format_filter
    @query.and(Pipeline.where(id: search_format_ids))
  end

  def search_user_ids
    User.where('username LIKE ?', @words).pluck(:id)
  end

  def search_source_ids
    HarvestDefinition.where('source_id LIKE ?', @words).pluck(:pipeline_id)
  end

  def search_format_ids
    ExtractionDefinition.where(format: @format).pluck(:pipeline_id)
  end
end
