# frozen_string_literal: true

# Where a block's transformed records get written. Kept apart from HarvestDefinition#kind,
# which says where a block sits in the pipeline, because the two are not the same question:
# a tagging block extracts and transforms exactly like a harvest, but writes its own
# secondary fragment onto records owned by other sources rather than their primary one.
class LoadDefinition < ApplicationRecord
  belongs_to :pipeline
  belongs_to :last_edited_by, class_name: 'User', optional: true

  has_many :harvest_definitions, dependent: :nullify

  # primary_fragment   - create or update the record's primary fragment. What a normal
  #                      harvest does, and the only kind allowed to flush.
  # secondary_fragment - write this block's own source-keyed fragment and leave the primary
  #                      one alone. Requires a non-zero priority: at zero the API selects
  #                      the primary fragment and nils every mutable field the payload does
  #                      not carry.
  # enrichment         - post a fragment to a record already fetched from the destination.
  # file               - write to disk for the next block instead of to the API.
  enum :kind, { primary_fragment: 0, secondary_fragment: 1, enrichment: 2, file: 3 }

  # The kind a block would load as if it had no load definition of its own. Only used
  # while load_definition_id is still nullable - see HarvestDefinition#load_kind.
  KIND_FOR_BLOCK_KIND = {
    'harvest' => 'primary_fragment',
    'enrichment' => 'enrichment',
    'preprocess' => 'file'
  }.freeze

  validates :name, uniqueness: true
  validates :priority, numericality: { only_integer: true }

  validate :priority_agrees_with_kind

  after_create do
    if name.blank?
      self.name = "#{id}_#{kind}-load"
      save!
    end
  end

  def to_h
    {
      id:,
      name:,
      kind:
    }
  end

  def shared?
    @shared = harvest_definitions.count > 1 if @shared.nil?
    @shared
  end

  def clone(pipeline, name)
    LoadDefinition.new(dup.attributes.merge(name:, pipeline:))
  end

  private

  # Priority is how the destination decides which fragment to write, so it cannot disagree
  # with the fragment this definition says it writes. Only the standard load writes the
  # primary fragment; the two that write a secondary one need a priority of their own, and an
  # enrichment is no exception - at 0 it writes the primary fragment through the fragments
  # endpoint, which is what it says it does not do.
  def priority_agrees_with_kind
    return if priority.blank?

    if writes_secondary_fragment? && priority.zero?
      errors.add(:priority, 'must not be 0 - at 0 the destination writes the primary fragment ' \
                            'instead, blanking every field this block does not set')
    elsif primary_fragment? && !priority.zero?
      errors.add(:priority, 'must be 0 to write the primary fragment')
    end
  end

  def writes_secondary_fragment?
    secondary_fragment? || enrichment?
  end
end
