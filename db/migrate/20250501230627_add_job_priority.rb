class AddJobPriority < ActiveRecord::Migration[7.1]
  def change
    add_column :automations, :job_priority, :string
  end
end
