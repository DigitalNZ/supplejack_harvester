# frozen_string_literal: true

class AddSourceIdToTransformationDefinition < ActiveRecord::Migration[7.0]
  def change
    add_column :transformation_definitions, :source_id, :string, null: false
  end
end
