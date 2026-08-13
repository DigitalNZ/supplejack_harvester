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

  # Named for what the block does to the destination record rather than for the enum value,
  # which only means something if you already know how fragments merge.
  LOAD_KIND_LABELS = {
    'primary_fragment' => 'The record itself (primary fragment)',
    'secondary_fragment' => 'The fragment based on source_id and priority (secondary fragment)',
    'enrichment' => 'A fragment on records fetched from the destination (enrichment)',
    'file' => 'A file for the next block to read (pre-processing)'
  }.freeze

  def load_kind_label(kind)
    LOAD_KIND_LABELS[kind]
  end

  def load_kind_options
    LOAD_KIND_LABELS.map { |kind, label| [label, kind] }
  end

  # What a block of this kind used to load as before it could be told, so adding a load
  # definition to an existing block does not silently change how it writes.
  def default_load_kind(harvest_definition)
    LoadDefinition::KIND_FOR_BLOCK_KIND.fetch(harvest_definition.kind, 'primary_fragment')
  end

  # A fragment that is not the primary one needs a priority of its own: fragments merge
  # lowest first, so each new one sits below the last rather than tying with it. This is
  # where the default the "Add enrichment" form used to carry now lives. The primary
  # fragment is 0 by definition, and a block writing to disk has no fragment at all.
  def default_load_priority(harvest_definition)
    return 0 if %w[primary_fragment file].include?(default_load_kind(harvest_definition))

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
