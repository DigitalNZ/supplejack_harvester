# frozen_string_literal: true

class AddDefinitionsToRunToHarvestJob < ActiveRecord::Migration[7.0]
  def change
    add_column :harvest_jobs, :harvest_definitions_to_run, :string
  end
end
