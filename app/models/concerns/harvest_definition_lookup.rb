# frozen_string_literal: true

# Shared behavior for models that need to look up harvest definitions
# based on pipeline and harvest_definition_ids
module HarvestDefinitionLookup
  extend ActiveSupport::Concern

  def harvest_definitions
    return [] unless pipeline
    return Pipeline.find(pipeline_id).harvest_definitions if harvest_definition_ids.blank?

    HarvestDefinition.where(id: harvest_definition_ids)
  end
end
