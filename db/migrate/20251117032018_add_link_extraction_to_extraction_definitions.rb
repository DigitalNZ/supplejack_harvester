class AddLinkExtractionToExtractionDefinitions < ActiveRecord::Migration[7.2]
  def change
    add_column :extraction_definitions, :link_extraction_enabled, :boolean, default: false, null: false
    add_column :extraction_definitions, :link_selector, :string
    add_column :extraction_definitions, :link_extraction_format, :string, default: 'auto', null: false
    add_column :extraction_definitions, :source_automation_step_position, :integer
  end
end
