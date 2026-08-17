# frozen_string_literal: true

class HarvestDefinition < ApplicationRecord
  belongs_to :pipeline
  belongs_to :content_source, optional: true

  belongs_to :extraction_definition, optional: true
  belongs_to :extraction_job, optional: true

  belongs_to :transformation_definition, optional: true

  # the before_destroy needs to be here (before any other dependent: :destroy statements)
  before_destroy :destroy_associated_definitions, prepend: true

  has_many :harvest_jobs, dependent: :destroy

  validates :source_id, presence: true

  enum :kind, { harvest: 0, enrichment: 1, preprocess: 2 }

  # A block with no kind cannot be run: TransformationWorker reads preprocess? as false and
  # queues a load for it, and Load::Execution then finds neither a harvest nor an enrichment
  # to post, so it returns nil and dies on nil.status - which is what happened to a block on
  # UAT whose kind was null. An invalid kind never gets this far, because the enum raises on
  # assignment, but nil does: "" casts to nil silently, and the column allows it.
  validates :kind, presence: true

  after_create do
    self.name = "#{id}_#{kind}"
    save!
  end

  def destroy_definition(definition)
    definition.destroy unless definition.nil? || definition.shared?
  end

  def destroy_associated_definitions
    destroy_definition(extraction_definition)
    destroy_definition(transformation_definition)
  end

  def completed_harvest_jobs?
    @completed_harvest_jobs ||= harvest_jobs.completed.any?
  end

  # Extraction jobs a picker can offer for this definition: data still on
  # disk, newest first. Nil when there is no extraction definition yet.
  def available_extraction_jobs
    return if extraction_definition.blank?

    extraction_definition.extraction_jobs.not_purged.order(created_at: :desc)
  end

  # A block after the first in the chain works from the records the block before it
  # wrote, rather than seeding its own extraction. Enrichments are never in the chain:
  # they iterate records back out of the destination API.
  def consumes_preprocess_output?
    !enrichment? && position.to_i.positive?
  end

  # The block position whose output this block reads.
  def preceding_position
    position.to_i - 1
  end

  def ready_to_run?
    return false if extraction_definition.blank?
    return false if transformation_definition.blank?
    return false if transformation_definition.fields.empty?

    true
  end

  def to_h
    {
      id:,
      name:,
      pipeline: {
        id: pipeline.id,
        name: pipeline.name,
        harvests: pipeline.harvest_definitions.harvest.count,
        enrichments: pipeline.enrichments.count
      }
    }
  end

  def clone(pipeline)
    HarvestDefinition.new(dup.attributes.merge(pipeline:))
  end
end
