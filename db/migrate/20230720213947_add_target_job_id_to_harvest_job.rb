# frozen_string_literal: true

class AddTargetJobIdToHarvestJob < ActiveRecord::Migration[7.0]
  def change
    add_column :harvest_jobs, :target_job_id, :string
    remove_column :extraction_definitions, :job_id
  end
end
