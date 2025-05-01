class AddJobPriorityToAutomation < ActiveRecord::Migration[7.1]
  def change
    add_column :automations, :job_priority, :string
    add_column :automation_templates, :job_priority, :string
  end
end
