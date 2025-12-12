# frozen_string_literal: true

module HarvestDefinitionLookup
  extend ActiveSupport::Concern

  def harvest_definitions
    return [] unless pipeline
    return Pipeline.find(pipeline_id).harvest_definitions if harvest_definition_ids.blank?

    HarvestDefinition.where(id: harvest_definition_ids)
  end
end
