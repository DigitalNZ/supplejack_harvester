class AddLinkSelectorToAutomationSteps < ActiveRecord::Migration[7.2]
  def change
    add_column :automation_steps, :link_selector, :string
  end
end
