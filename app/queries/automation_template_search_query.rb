# frozen_string_literal: true

class AutomationTemplateSearchQuery
  def initialize(params)
    @words = sanitized_words(params[:search])
    @query = AutomationTemplate
  end

  def call
    return @query if @words.blank?

    @query = or_words_filters
    @query
  end

  private

  def sanitized_words(words)
    words = AutomationTemplate.sanitize_sql_like(words || '')
    return nil if words.empty?

    "%#{words}%"
  end

  def or_words_filters
    @query.where('name LIKE ?', @words)
          .or(AutomationTemplate.where('description LIKE ?', @words))
          .or(AutomationTemplate.where(last_edited_by_id: search_user_ids))
          .or(AutomationTemplate.where(id: search_destination_ids))
  end

  def search_user_ids
    User.where('username LIKE ?', @words).pluck(:id)
  end

  def search_destination_ids
    destination_ids = Destination.where('name LIKE ?', @words).pluck(:id)
    AutomationTemplate.where(destination_id: destination_ids).pluck(:id)
  end
end 