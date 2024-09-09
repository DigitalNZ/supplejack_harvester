# frozen_string_literal: true

class ChangeParameterContentColumnSize < ActiveRecord::Migration[7.1]
  def up
    change_column :parameters, :content, :text
  end

  def down
    change_column :parameters, :content, :string
  end
end
