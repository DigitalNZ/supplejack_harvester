# frozen_string_literal: true

class CreateParameters < ActiveRecord::Migration[7.0]
  def change
    create_table :parameters do |t|
      t.string  :key
      t.string  :value
      t.integer :kind, default: 0
      t.boolean :dynamic, default: false
      t.timestamps
    end

    add_reference :parameters, :request, null: false
  end
end
