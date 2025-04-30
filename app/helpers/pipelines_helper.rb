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

  def job_priority_options(job_priorities)
    [['No priority', nil]] + job_priorities.map { |priority| [priority.humanize, priority] }
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
