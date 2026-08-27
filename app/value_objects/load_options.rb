# frozen_string_literal: true

# What a block may be told about how it loads: which kinds it can choose between, which of
# the settings mean anything for them, and what to start a new load definition on.
#
# Every answer follows from the block's kind (LoadDefinition::KINDS_FOR_BLOCK_KIND), so the
# form cannot offer a choice the model will then refuse - a pre-processing block writes a
# file for the next block and nothing else, an enrichment posts to records it fetched, and
# only a harvest picks between writing the record itself and writing its own fragment.
class LoadOptions
  # A name and then what it does to the destination record, because the enum value on its own
  # only means something if you already know how fragments merge. Wording from the PO.
  KIND_LABELS = {
    'primary_fragment' => 'Standard – Writes to the primary fragment',
    'secondary_fragment' => 'Secondary fragment – Writes to a secondary fragment (not the primary fragment)',
    'enrichment' => 'Enrichment – Writes to a secondary fragment (not the primary fragment)',
    'preprocessed_data' => 'Preprocessing – Gathers data for the next block (without writing records)'
  }.freeze

  def initialize(harvest_definition)
    @harvest_definition = harvest_definition
  end

  # A block with one option still gets a select, which says the choice is made for it.
  def kind_options
    kinds.map { |kind| [KIND_LABELS[kind], kind] }
  end

  # A block writing a file posts nothing, so there is no fragment for a priority to pick.
  def asks_for_priority?
    posts_to_the_api?
  end

  # Nor is there a response to wait on.
  def asks_for_read_timeout?
    posts_to_the_api?
  end

  # Only a request that carries a batch has a size to set, and an enrichment's does not: it
  # posts the single record it holds the destination's id for, so the size LoadWorker slices
  # at decides nothing about the request - see Load::Execution#enrichment_request.
  def asks_for_batch_size?
    posts_to_the_api? && kinds.exclude?('enrichment')
  end

  # Only an enrichment can leave a record partial by not arriving: Load::Execution sends
  # required_fragments on that path alone, so nothing else has any use for the answer.
  def asks_for_required_fragment?
    kinds.include?('enrichment')
  end

  # What a block of this kind used to load as before it could be told, so adding a load
  # definition to an existing block does not silently change how it writes.
  def default_kind
    LoadDefinition.default_kind_for_block_kind(block_kind) || 'primary_fragment'
  end

  # A fragment that is not the primary one needs a priority of its own: fragments merge
  # lowest first, so each new one sits below the last rather than tying with it. This is
  # where the default the "Add enrichment" form used to carry now lives. The primary
  # fragment is 0 by definition, and a block writing to disk has no fragment at all.
  def default_priority
    return 0 if %w[primary_fragment preprocessed_data].include?(default_kind)

    (LoadDefinition.where(pipeline_id: @harvest_definition.pipeline_id).minimum(:priority) || 0) - 1
  end

  private

  def posts_to_the_api?
    kinds.exclude?('preprocessed_data')
  end

  def kinds
    @kinds ||= LoadDefinition.kinds_for_block_kind(block_kind)
  end

  def block_kind
    @harvest_definition.kind
  end
end
