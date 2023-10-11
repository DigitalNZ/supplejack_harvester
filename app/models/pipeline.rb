# frozen_string_literal: true

class Pipeline < ApplicationRecord
  paginates_per 19 # not 20 because of the "Create new pipeline" button

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

  def self.sanitized_words(words)
    words = sanitize_sql_like(words || '')
    return nil if words.empty?

    "%#{words}%"
  end

  def self.search_user_ids(words)
    User.where('username LIKE ?', words).pluck(:id)
  end

  def self.search_source_ids(words)
    HarvestDefinition.where('source_id LIKE ?', words).pluck(:pipeline_id)
  end

  def self.search_format_ids(format)
    ExtractionDefinition.where(format:).pluck(:pipeline_id)
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
end
