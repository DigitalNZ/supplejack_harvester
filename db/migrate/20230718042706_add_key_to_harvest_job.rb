# frozen_string_literal: true

class AddKeyToHarvestJob < ActiveRecord::Migration[7.0]
  def change
    add_column :harvest_jobs, :key, :string
    add_index :harvest_jobs,  :key, unique: true
  end
end
