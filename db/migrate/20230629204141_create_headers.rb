# frozen_string_literal: true

class CreateHeaders < ActiveRecord::Migration[7.0]
  def change
    create_table :headers do |t|
      t.string :name
      t.string :value

      t.timestamps
    end

    add_reference :headers, :extraction_definition, null: false
  end
end
