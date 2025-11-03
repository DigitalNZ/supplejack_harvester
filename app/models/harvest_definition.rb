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

  enum :kind, { harvest: 0, enrichment: 1 }

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
