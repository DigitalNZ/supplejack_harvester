class AddExtractionDefinitionToAutomationStepTemplates < ActiveRecord::Migration[7.2]
  def change
    add_column :automation_step_templates, :extraction_definition_id, :bigint
    add_index :automation_step_templates, :extraction_definition_id
  end
end
