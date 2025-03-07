# frozen_string_literal: true

class CreateAutomationTemplates < ActiveRecord::Migration[7.1]
  def change
    create_table :automation_templates do |t|
      t.string :name, null: false
      t.text :description
      t.references :destination, foreign_key: true
      t.references :last_edited_by, foreign_key: { to_table: :users }

      t.timestamps
    end
    
    add_index :automation_templates, :name, unique: true
  end
end 