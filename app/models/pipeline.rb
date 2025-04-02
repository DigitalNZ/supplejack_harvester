# frozen_string_literal: true

class Pipeline < ApplicationRecord
  paginates_per 20

  has_many :harvest_definitions, dependent: :destroy
  has_many :harvest_jobs, through: :harvest_definitions
  belongs_to :last_edited_by, class_name: 'User', optional: true

  has_many :pipeline_jobs, dependent: :destroy
  has_many :schedules, dependent: :destroy
  has_many :automation_step_templates, dependent: :destroy
  has_many :automation_templates, -> { distinct }, through: :automation_step_templates

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

  def complete_finished_jobs!
    running_reports = pipeline_jobs.flat_map(&:harvest_reports).select do |report|
      report.status == 'running'
    end

    running_reports.each do |report|
      report.update(transformation_status: 'completed') if report.transformation_workers_completed?
      report.update(load_status: 'completed') if report.load_workers_completed?
      report.update(delete_status: 'completed') if report.delete_workers_completed?
    end
  end
end
