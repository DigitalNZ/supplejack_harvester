# frozen_string_literal: true

class AddConditionToFields < ActiveRecord::Migration[7.0]
  def change
    add_column :fields, :kind, :integer, default: 0
    add_column :fields, :condition, :integer, default: 0
  end
end
