# frozen_string_literal: true

class MoveSourceIdToHarvestDefinition < ActiveRecord::Migration[7.0]
  def up
    remove_column :transformation_definitions, :source_id
    add_column    :harvest_definitions, :source_id, :string
    change_column :transformation_definitions, :name, :string, null: true
  end

  def down
    add_column    :transformation_definitions, :source_id, :string
    remove_column :harvest_definitions, :source_id
    change_column :transformation_definitions, :name, :string, null: false
  end
end
