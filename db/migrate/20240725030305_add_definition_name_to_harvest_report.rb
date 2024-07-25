class AddDefinitionNameToHarvestReport < ActiveRecord::Migration[7.1]
  def change
    add_column :harvest_reports, :definition_name, :string
  end
end
