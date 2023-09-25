# frozen_string_literal: true

class AddTransformationDefinitionReference < ActiveRecord::Migration[7.0]
  def change
    add_reference :transformation_definitions, :original_transformation_definition, null: true,
                                                                                    index: { name: 'index_tds_on_original_td_id' }
  end
end
