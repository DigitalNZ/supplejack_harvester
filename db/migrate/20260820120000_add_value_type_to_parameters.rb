# frozen_string_literal: true

class AddValueTypeToParameters < ActiveRecord::Migration[8.0]
  def change
    add_column :parameters, :value_type, :integer, default: 0, null: false
  end
end
