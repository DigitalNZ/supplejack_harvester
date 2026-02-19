class DeleteKeyOnHarvestJobAndPipelineJob < ActiveRecord::Migration[7.2]
  def up
    # harvest_jobs.key
    if index_exists?(:harvest_jobs, :key)
      remove_index :harvest_jobs, :key
    end
    remove_column :harvest_jobs, :key, :string

    # pipeline_jobs.key
    if index_exists?(:pipeline_jobs, :key)
      remove_index :pipeline_jobs, :key
    end
    remove_column :pipeline_jobs, :key, :string
  end

  def down
    # harvest_jobs.key
    add_column :harvest_jobs, :key, :string
    add_index  :harvest_jobs, :key, unique: true, name: "index_harvest_jobs_on_key"

    # pipeline_jobs.key
    add_column :pipeline_jobs, :key, :string
    add_index  :pipeline_jobs, :key, unique: true, name: "index_pipeline_jobs_on_key"
  end
end
