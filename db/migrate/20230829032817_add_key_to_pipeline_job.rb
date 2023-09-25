# frozen_string_literal: true

class AddKeyToPipelineJob < ActiveRecord::Migration[7.0]
  def change
    add_column :pipeline_jobs, :key, :string
    add_index :pipeline_jobs,  :key, unique: true
  end

  add_reference :harvest_definitions, :harvest_report
  add_reference :harvest_reports, :harvest_definition
  add_reference :pipeline_jobs, :pipeline
end
