class AddAutomationTemplateAssociationToSchedule < ActiveRecord::Migration[7.1]
  def change
    change_column_null :schedules, :pipeline_id, true
    add_reference :schedules, :automation_template, null: true
  end
end
