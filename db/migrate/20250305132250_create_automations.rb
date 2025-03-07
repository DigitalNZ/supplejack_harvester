# frozen_string_literal: true

class CreateAutomations < ActiveRecord::Migration[7.1]
  def change
    create_table :automations do |t|
      t.string :name, null: false
      t.text :description
      t.references :destination, null: false, foreign_key: true
      t.references :automation_template, null: true, foreign_key: true, index: true

      t.timestamps
    end
  end
end 