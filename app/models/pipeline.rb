# frozen_string_literal: true

class Pipeline < ApplicationRecord
  paginates_per 20

  has_many :harvest_definitions, dependent: :destroy
  has_many :harvest_jobs, through: :harvest_definitions
  belongs_to :last_edited_by, class_name: 'User', optional: true

  has_many :pipeline_tags, dependent: :destroy
  has_many :tags, through: :pipeline_tags

  has_many :pipeline_jobs, dependent: :destroy
  has_many :schedules, dependent: :destroy
  has_many :automation_step_templates, dependent: :destroy
  has_many :automation_templates, -> { distinct }, through: :automation_step_templates

  validates :name, presence: true, uniqueness: true

  # Tag filters combine with AND: a pipeline has to carry every tag asked for, not any
  # of them. One subquery per slug rather than a grouped COUNT keeps the relation a
  # plain, ungrouped one, so it still composes with search, ordering, pagination and
  # nests as a subquery for the jobs list filter. A slug no tag uses matches nothing,
  # which is the honest answer for a filter naming a tag that has been deleted.
  scope :tagged_with_all, lambda { |slugs|
    slugs = Array(slugs).map(&:to_s).compact_blank.uniq
    next all if slugs.empty?

    slugs.reduce(all) do |query, slug|
      query.where(id: PipelineTag.where(tag: Tag.where(slug:)).select(:pipeline_id))
    end
  }

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

  def preprocesses
    harvest_definitions.where(kind: 'preprocess').order(:position)
  end

  # The processing chain: preprocess and harvest blocks in position order.
  # Enrichment definitions are deliberately excluded - they are not part of the
  # position-ordered chain and are enqueued separately after the harvest loads
  # (see PipelineJob#enqueue_enrichment_jobs). The `id` tiebreaker keeps ordering
  # deterministic when two blocks share a position (e.g. legacy position 0 data).
  def ordered_blocks
    harvest_definitions.where.not(kind: :enrichment).order(:position, :id)
  end

  def ready_to_run?
    return false if harvest_definitions.empty?

    harvest_definitions.any?(&:ready_to_run?)
  end

  # This pipeline's runs that wrote pre-processed output for a block position, most
  # recent first. The one thing a block at position > 0 can be fed from: the Run
  # modal's input choices, the request preview, and a standalone extraction all pick
  # from this list.
  def runs_with_output_at(position)
    pipeline_jobs
      .where(id: PreProcess::Output.pipeline_job_ids_with_output(position))
      .order(created_at: :desc)
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
