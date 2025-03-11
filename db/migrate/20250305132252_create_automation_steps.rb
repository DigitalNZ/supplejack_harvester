# frozen_string_literal: true

class CreateAutomationSteps < ActiveRecord::Migration[7.1]
  def up
    create_table :automation_steps do |t|
      t.references :automation, null: false, foreign_key: true
      t.references :pipeline, null: false, foreign_key: true
      t.references :launched_by, null: true, foreign_key: { to_table: :users }
      t.integer :position, null: false, default: 0
      t.text :harvest_definition_ids
      t.timestamps
    end
    
    add_index :automation_steps, [:automation_id, :position], unique: true
  end
end 