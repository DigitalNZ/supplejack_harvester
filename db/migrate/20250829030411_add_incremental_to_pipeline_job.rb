class AddIncrementalToPipelineJob < ActiveRecord::Migration[7.1]
  def change
    add_column :pipeline_jobs, :incremental_enrichment, :boolean, default: false
  end
end
