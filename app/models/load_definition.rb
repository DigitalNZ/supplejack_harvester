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
  # preprocessed_data  - write to disk for the next block instead of to the API.
  enum :kind, { primary_fragment: 0, secondary_fragment: 1, enrichment: 2, preprocessed_data: 3 }

  # What a block of each kind is allowed to do with its records, most typical first. Only a
  # harvest has a choice: write the record itself, or add its own fragment to records other
  # sources own. An enrichment posts to records it fetched from the destination and nothing
  # else, and a pre-processing block only ever writes a file for the next block to read -
  # anything else and the block after it gets nothing.
  KINDS_FOR_BLOCK_KIND = {
    'harvest' => %w[primary_fragment secondary_fragment],
    'enrichment' => %w[enrichment],
    'preprocess' => %w[preprocessed_data]
  }.freeze

  def self.kinds_for_block_kind(block_kind)
    KINDS_FOR_BLOCK_KIND.fetch(block_kind, [])
  end

  # The kind a block loads as when it has no load definition of its own. Only used while
  # load_definition_id is still nullable - see HarvestDefinition#load_kind.
  def self.default_kind_for_block_kind(block_kind)
    kinds_for_block_kind(block_kind).first
  end

  # How long to wait for the destination to answer, offered as a few choices rather than a free
  # number: the only useful answers are "the default", "a bit longer" and "much longer", and a
  # typo in a free field is a harvest that either gives up too early or holds a worker for an
  # hour. nil means the app-wide default in config/initializers/faraday.rb stands.
  READ_TIMEOUT_OPTIONS = { 30 => '30 seconds', 60 => '1 minute', 120 => '2 minutes', 180 => '3 minutes' }.freeze

  # What a definition that says nothing waits: the app-wide default from
  # config/initializers/faraday.rb, which HTTP_READ_TIMEOUT sets. Read back from Faraday rather
  # than from ENV so the form cannot disagree with what the request will actually do.
  def self.default_read_timeout = Faraday.default_connection_options.request.timeout

  # Plain English rather than a number of seconds, which reads as a timeout of thirty when it is
  # two minutes. A value the switch does not name - HTTP_READ_TIMEOUT is free to be anything -
  # is described in seconds rather than left blank.
  def self.read_timeout_label(seconds) = READ_TIMEOUT_OPTIONS.fetch(seconds) { "#{seconds} seconds" }

  # For a select. Leaving it unset means the default, so that entry says which value that is
  # rather than only that it exists; and the choice equal to it is dropped, because offering
  # both would list the same number twice for the same wait.
  #
  # Unless this definition is the one pinned to that value, which keeps its entry: nothing in
  # the list would otherwise match what is stored, and opening the form would quietly turn a
  # pinned timeout into one that follows the default.
  def read_timeout_options
    settings = self.class
    default = settings.default_read_timeout
    offered = read_timeout == default ? READ_TIMEOUT_OPTIONS : READ_TIMEOUT_OPTIONS.except(default)

    [["Default (#{settings.read_timeout_label(default)})", nil]] + offered.map { |seconds, label| [label, seconds] }
  end

  # What LoadWorker has always sliced at, and what a block with no load definition still gets.
  DEFAULT_BATCH_SIZE = 100

  validates :name, uniqueness: true
  validates :priority, numericality: { only_integer: true }
  validates :read_timeout, inclusion: { in: READ_TIMEOUT_OPTIONS.keys }, allow_nil: true
  validates :batch_size,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: DEFAULT_BATCH_SIZE }

  validate :priority_agrees_with_kind
  validate :kind_suits_the_blocks_loading_through_it

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

    zero = priority.zero?

    if writes_secondary_fragment? && zero
      errors.add(:priority, 'must not be 0 - at 0 the destination writes the primary fragment ' \
                            'instead, blanking every field this block does not set')
    elsif primary_fragment? && !zero
      errors.add(:priority, 'must be 0 to write the primary fragment')
    end
  end

  def writes_secondary_fragment?
    secondary_fragment? || enrichment?
  end

  # Editing a load definition must not take it somewhere its blocks cannot follow. On create
  # there are no blocks yet, and HarvestDefinition validates the pairing from its side as the
  # block picks the definition up.
  #
  # Asked of the database rather than the association, which caches whatever it held the last
  # time this record was validated - for a definition created and then attached to, that is an
  # empty collection, and the check would pass on a stale answer.
  def kind_suits_the_blocks_loading_through_it
    named = blocks_that_cannot_follow.map { |block| "the #{block.kind} block #{block.source_id}" }
    return if named.empty?

    errors.add(:kind, "is not something #{named.to_sentence} can do")
  end

  def blocks_that_cannot_follow
    return [] if id.blank?

    HarvestDefinition.where(load_definition_id: id).reject do |block|
      self.class.kinds_for_block_kind(block.kind).include?(kind)
    end
  end
end
