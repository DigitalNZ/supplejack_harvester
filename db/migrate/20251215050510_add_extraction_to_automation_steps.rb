class AddExtractionToAutomationSteps < ActiveRecord::Migration[7.0]
  def change
    add_reference :automation_steps, :extraction_definition, foreign_key: true, null: true
    add_reference :automation_steps, :extraction_job, foreign_key: true, null: true
    add_column :automation_steps, :skip_transformation, :boolean, default: false, null: false
  end
end