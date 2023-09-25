# frozen_string_literal: true

class AddIndexToDestinationName < ActiveRecord::Migration[7.0]
  def change
    add_index :destinations, :name, unique: true
  end
end
