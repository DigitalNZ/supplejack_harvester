# frozen_string_literal: true

class AddNameToHarvestJob < ActiveRecord::Migration[7.0]
  def change
    add_column :harvest_jobs, :name, :string
  end
end
