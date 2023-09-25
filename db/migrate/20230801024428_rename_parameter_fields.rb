# frozen_string_literal: true

class RenameParameterFields < ActiveRecord::Migration[7.0]
  def change
    rename_column :parameters, :key, :name
    rename_column :parameters, :value, :content
  end
end
