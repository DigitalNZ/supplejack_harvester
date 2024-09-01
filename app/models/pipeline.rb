# frozen_string_literal: true

class Pipeline < ApplicationRecord
  paginates_per 20

  has_many :harvest_definitions, dependent: :destroy
  has_many :harvest_jobs, through: :harvest_definitions
  belongs_to :last_edited_by, class_name: 'User', optional: true

  has_many :pipeline_jobs, dependent: :destroy
  has_many :schedules, dependent: :destroy

  validates :name, presence: true, uniqueness: true

  def self.search(words, format)
    words = sanitized_words(words)
    return self if words.blank? && format.blank?

    query = where('name LIKE ?', words)
            .or(where('description LIKE ?', words))
            .or(where(last_edited_by_id: search_user_ids(words)))
            .or(where(id: search_source_ids(words)))

    query = query.and(where(id: search_format_ids(format))) if format.present?
    query
  end

  def harvest
    harvest_definitions.find_by(kind: 'harvest')
  end

  def enrichments
    harvest_definitions.where(kind: 'enrichment')
  end

  def ready_to_run?
    return false if harvest_definitions.empty?

    harvest_definitions.any?(&:ready_to_run?)
  end

  def to_h
    {
      id:,
      name:,
      created_at:,
      updated_at:
    }
  end
end
