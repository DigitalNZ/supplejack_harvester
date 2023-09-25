# frozen_string_literal: true

class AddHarvestDefinitionsToRunToPipeline < ActiveRecord::Migration[7.0]
  def change
    remove_column :harvest_jobs, :harvest_definitions_to_run, :string
    add_column :pipeline_jobs, :harvest_definitions_to_run, :string
  end
end
