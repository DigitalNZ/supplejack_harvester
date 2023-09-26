# frozen_string_literal: true

class HarvestDefinition < ApplicationRecord
  belongs_to :pipeline
  belongs_to :content_source, optional: true

  belongs_to :extraction_definition, optional: true
  belongs_to :extraction_job, optional: true

  belongs_to :transformation_definition, optional: true

  has_many :harvest_jobs, dependent: :destroy

  validates :source_id, presence: true

  enum :kind, { harvest: 0, enrichment: 1 }

  before_destroy :destroy_associated_definitions

  after_create do
    self.name = "#{pipeline.name.parameterize}__#{kind}-#{id}"
    save!
  end

  def destroy_associated_definitions
    extraction_definition.destroy unless extraction_definition.nil? || extraction_definition.shared?
    transformation_definition.destroy unless transformation_definition.nil? || transformation_definition.shared?
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
