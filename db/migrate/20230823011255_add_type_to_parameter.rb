# frozen_string_literal: true

class AddTypeToParameter < ActiveRecord::Migration[7.0]
  def change
    add_column :parameters, :content_type, :integer, default: 0
    remove_column :parameters, :dynamic
  end
end
