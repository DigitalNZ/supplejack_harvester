class AddIncrementalToPipelineJob < ActiveRecord::Migration[7.1]
  def change
    add_column :pipeline_jobs, :skip_previously_enriched, :boolean, default: false
  end
end
