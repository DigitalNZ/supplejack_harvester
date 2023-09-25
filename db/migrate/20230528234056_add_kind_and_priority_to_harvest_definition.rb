# frozen_string_literal: true

class AddKindAndPriorityToHarvestDefinition < ActiveRecord::Migration[7.0]
  def change
    add_column :harvest_definitions, :kind, :integer, default: 0
    add_column :harvest_definitions, :priority, :integer, default: 0
  end
end
