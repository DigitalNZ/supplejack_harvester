# frozen_string_literal: true

class AddExtractionDefinitionReference < ActiveRecord::Migration[7.0]
  def change
    add_reference :extraction_definitions, :original_extraction_definition, null: true,
                                                                            index: { name: 'index_eds_on_original_ed_id' }
  end
end
