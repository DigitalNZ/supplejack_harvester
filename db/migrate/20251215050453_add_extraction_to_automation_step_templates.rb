class AddExtractionToAutomationStepTemplates < ActiveRecord::Migration[7.0]
  def change
    add_reference :automation_step_templates, :extraction_definition, foreign_key: true, null: true
    add_column :automation_step_templates, :skip_transformation, :boolean, default: false, null: false
  end
end