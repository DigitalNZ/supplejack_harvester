class DeleteNameOnPipelineJobs < ActiveRecord::Migration[7.2]
  def change
    remove_column :pipeline_jobs, :name, :string
  end
end
