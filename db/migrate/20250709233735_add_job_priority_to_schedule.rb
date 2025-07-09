class AddJobPriorityToSchedule < ActiveRecord::Migration[7.1]
  def change
    add_column :schedules, :job_priority, :string
  end
end
