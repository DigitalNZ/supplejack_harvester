# frozen_string_literal: true

class AddPositionToHarvestDefinitions < ActiveRecord::Migration[7.1]
  def change
    add_column :harvest_definitions, :position, :integer, default: 0, null: false
  end
end
