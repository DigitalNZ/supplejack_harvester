# frozen_string_literal: true

module PipelinesHelper
  def definition_edit_text(definition, type)
    return "Edit shared #{type.capitalize}" if definition.shared?

    "Edit #{type}"
  end

  def definition_delete_text(definition, type)
    if definition.shared?
      "This will NOT delete the #{type} definition '#{definition.name}' as it is shared with another pipeline."
    else
      "This WILL delete the #{type} definition '#{definition.name} as it is NOT shared with another pipeline."
    end
  end

  def job_priority_options
    ENV['JOB_PRIORITIES'].split(',').map { |priority| [priority.humanize, priority] }
  end

  # A name and then what it does to the destination record, because the enum value on its own
  # only means something if you already know how fragments merge. Wording from the PO.
  LOAD_KIND_LABELS = {
    'primary_fragment' => 'Standard – Writes to the primary fragment',
    'secondary_fragment' => 'Secondary fragment – Writes to a secondary fragment (not the primary fragment)',
    'enrichment' => 'Enrichment – Writes to a secondary fragment (not the primary fragment)',
    'preprocessed_data' => 'Preprocessing – Gathers data for the next block (without writing records)'
  }.freeze

  # Nothing at all when a block is fine, rather than an empty element, so the caller does not
  # have to ask twice. Unnamed: it is rendered in the block's own row, next to its name.
  def cannot_run_notice(problems)
    return if problems.empty?

    tag.small("Cannot run: #{problems.to_sentence}.", class: 'd-block text-danger')
  end

  # Only what this block can actually do, so the form cannot offer a choice the model will then
  # refuse. A block with one option still gets a select, which says the choice is made for it.
  def load_kind_options(harvest_definition)
    LoadDefinition.kinds_for_block_kind(harvest_definition.kind).map { |kind| [LOAD_KIND_LABELS[kind], kind] }
  end

  # A block writing a file posts nothing, so there is no fragment for a priority to pick.
  def load_asks_for_priority?(harvest_definition)
    LoadDefinition.kinds_for_block_kind(harvest_definition.kind).exclude?('preprocessed_data')
  end

  # Only an enrichment can leave a record partial by not arriving: Load::Execution sends
  # required_fragments on that path alone, so nothing else has any use for the answer.
  def load_asks_for_required_fragment?(harvest_definition)
    LoadDefinition.kinds_for_block_kind(harvest_definition.kind).include?('enrichment')
  end

  # What a block of this kind used to load as before it could be told, so adding a load
  # definition to an existing block does not silently change how it writes.
  def default_load_kind(harvest_definition)
    LoadDefinition.default_kind_for_block_kind(harvest_definition.kind) || 'primary_fragment'
  end

  # A fragment that is not the primary one needs a priority of its own: fragments merge
  # lowest first, so each new one sits below the last rather than tying with it. This is
  # where the default the "Add enrichment" form used to carry now lives. The primary
  # fragment is 0 by definition, and a block writing to disk has no fragment at all.
  def default_load_priority(harvest_definition)
    return 0 if %w[primary_fragment preprocessed_data].include?(default_load_kind(harvest_definition))

    (LoadDefinition.where(pipeline_id: harvest_definition.pipeline_id).minimum(:priority) || 0) - 1
  end

  private

  def autocomplete_harvest_extraction_definitions
    ExtractionDefinition.all.harvest.sort_by(&:name).map(&:to_h).to_json
  end

  def autocomplete_harvest_transformation_definitions
    TransformationDefinition.all.harvest.sort_by(&:name).map(&:to_h).to_json
  end

  def autocomplete_enrichment_extraction_definitions
    ExtractionDefinition.all.enrichment.sort_by(&:name).map(&:to_h).to_json
  end

  def autocomplete_enrichment_transformation_definitions
    TransformationDefinition.all.enrichment.sort_by(&:name).map(&:to_h).to_json
  end
end
