# frozen_string_literal: true

module CardsHelper
  def extraction_card_subtitle(definition)
    total_pages = definition.extraction_jobs.not_purged.is_full.last&.documents&.total_pages
    [
      last_edited_by(definition),
      total_pages.nil? ? nil : pluralize(total_pages, 'page')
    ].compact.join(' | ')
  end

  def transformation_card_subtitle(definition)
    [
      last_edited_by(definition)
    ].compact.join(' | ')
  end
end
