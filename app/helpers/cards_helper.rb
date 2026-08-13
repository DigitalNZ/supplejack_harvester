# frozen_string_literal: true

module CardsHelper
  def extraction_card_subtitle(definition)
    total_pages = definition.extraction_jobs.is_full.last&.documents&.total_pages
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

  # The bare kind, not the sentence the editor's select spells out: on a card it sits beside
  # two other subtitles and only has to say which of the four this is. The priority goes with
  # it because the pair is what decides which fragment gets written.
  def load_card_subtitle(definition)
    [
      last_edited_by(definition),
      definition.kind,
      "priority #{definition.priority}"
    ].compact.join(' | ')
  end
end
