# frozen_string_literal: true

class CreateAutomationStepTemplates < ActiveRecord::Migration[7.1]
  def change
    create_table :automation_step_templates do |t|
      t.references :automation_template, null: false, foreign_key: true
      t.references :pipeline, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.text :harvest_definition_ids

      t.timestamps
    end
    
    add_index :automation_step_templates, [:automation_template_id, :position], name: 'index_automation_step_templates_on_template_id_and_position'
  end
end 