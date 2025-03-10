# frozen_string_literal: true

class AddForeignKeyToPipelineJobsAutomationStep < ActiveRecord::Migration[7.1]
  def change
    # First add the column if it doesn't exist
    unless column_exists?(:pipeline_jobs, :automation_step_id)
      add_reference :pipeline_jobs, :automation_step, index: true
    end
    
    # Then add the foreign key
    add_foreign_key :pipeline_jobs, :automation_steps, column: :automation_step_id
  end
end 