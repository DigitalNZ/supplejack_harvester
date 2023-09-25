# frozen_string_literal: true

class AddKindToTransformationDefinition < ActiveRecord::Migration[7.0]
  def change
    add_column :transformation_definitions, :kind, :integer, default: 0
  end
end
