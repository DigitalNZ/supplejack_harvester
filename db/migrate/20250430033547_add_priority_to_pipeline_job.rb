class AddPriorityToPipelineJob < ActiveRecord::Migration[7.1]
  def change
    add_column :pipeline_jobs, :job_priority, :string
  end
end
