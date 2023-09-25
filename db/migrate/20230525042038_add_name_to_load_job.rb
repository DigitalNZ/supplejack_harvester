# frozen_string_literal: true

class AddNameToLoadJob < ActiveRecord::Migration[7.0]
  def change
    add_column :load_jobs, :name, :text
  end
end
