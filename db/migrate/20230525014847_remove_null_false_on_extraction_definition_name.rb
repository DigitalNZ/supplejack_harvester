# frozen_string_literal: true

class RemoveNullFalseOnExtractionDefinitionName < ActiveRecord::Migration[7.0]
  def up
    change_column :extraction_definitions, :name, :string, null: true
  end

  def down
    change_column :extraction_definitions, :name, :string, null: false
  end
end
