# frozen_string_literal: true

class HarvestDefinition < ApplicationRecord
  belongs_to :pipeline
  belongs_to :content_source, optional: true

  belongs_to :extraction_definition, optional: true
  belongs_to :extraction_job, optional: true

  belongs_to :transformation_definition, optional: true
  belongs_to :load_definition, optional: true

  # the before_destroy needs to be here (before any other dependent: :destroy statements)
  before_destroy :destroy_associated_definitions, prepend: true

  has_many :harvest_jobs, dependent: :destroy

  validates :source_id, presence: true

  enum :kind, { harvest: 0, enrichment: 1, preprocess: 2 }

  # A block with no kind cannot be run: nothing maps nil onto a load kind, so
  # TransformationWorker does not take it for a block writing to disk and queues a load for
  # it, and Load::Execution then has no fragment it could be writing and raises. A block on
  # UAT whose kind was null is how this was found - at the time by returning nil and dying on
  # nil.status, before that path learnt to raise. An invalid kind never gets this far, because
  # the enum raises on assignment, but nil does: "" casts to nil silently, and the column
  # allows it.
  validates :kind, presence: true

  validate :load_definition_is_something_this_block_can_do

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
    destroy_definition(load_definition)
  end

  # How this block writes its records. Blocks predating load definitions, and any created
  # between the backfill and the editor learning to make them, have none - fall back to the
  # kind the block would have loaded as before load definitions existed. Falls away once
  # load_definition_id is made non-null.
  def load_kind
    load_definition&.kind || LoadDefinition.default_kind_for_block_kind(kind)
  end

  # See LoadDefinition::KINDS_FOR_BLOCK_KIND for which kinds go with which. Checked from both
  # sides: here as a block picks a definition up, and on the definition as it is edited.
  def load_definition_is_something_this_block_can_do
    return if load_definition.blank?

    block_kind = kind
    definition_kind = load_definition.kind
    return if LoadDefinition.kinds_for_block_kind(block_kind).include?(definition_kind)

    errors.add(:load_definition, "cannot be a #{definition_kind} load on a #{block_kind} block")
  end

  # Which fragment the destination writes to, and whether the record counts as active
  # without one. Both describe the write rather than the block, so the load definition owns
  # them; the columns on this table are only read for a block that has no load definition
  # yet, and go away with #load_kind's fallback.
  def load_priority
    load_definition&.priority || priority
  end

  def load_required_for_active_record?
    return required_for_active_record? if load_definition.nil?

    load_definition.required_for_active_record?
  end

  # How the request to the destination is made rather than what it carries. nil for the timeout
  # leaves the app-wide default standing - Api::Request drops the option entirely rather than
  # passing nil, which would clear it.
  delegate :read_timeout, to: :load_definition, prefix: :load, allow_nil: true

  def load_batch_size
    load_definition&.batch_size || LoadDefinition::DEFAULT_BATCH_SIZE
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
    configuration_problems.empty?
  end

  # Why this block cannot run, in words, so that whatever disables it can also say why.
  def configuration_problems
    BlockConfiguration.new(self).problems
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
