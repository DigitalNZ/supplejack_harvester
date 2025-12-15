class AddLinkSelectorToAutomationStepTemplates < ActiveRecord::Migration[7.2]
  def change
    add_column :automation_step_templates, :link_selector, :string
  end
end
