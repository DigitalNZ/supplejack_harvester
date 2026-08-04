# frozen_string_literal: true

# Links a newly created extraction/transformation definition to the owning
# harvest_definition block, and fixes up the auto-generated name when that block is a
# pre-processing block: the definition is deliberately created with kind: 'harvest'
# (see app/views/pipelines/_preprocess_definition.html.erb for why), so the model's
# after_create would name it "N_harvest-extraction" / "N_harvest-transformation".
# Rename it after its owning block instead. Only auto-generated names are touched -
# a user-supplied name is never overridden.
module DefinitionAttachment
  extend ActiveSupport::Concern

  private

  def attach_to_block(definition, type)
    @harvest_definition.update("#{type}_definition_id" => definition.id)
    rename_for_preprocess_block(definition, type)
  end

  def rename_for_preprocess_block(definition, type)
    return unless @harvest_definition.preprocess?
    return if params.dig("#{type}_definition", :name).present?

    definition.update!(name: "#{definition.id}_pre-processing-#{type}")
  end
end
