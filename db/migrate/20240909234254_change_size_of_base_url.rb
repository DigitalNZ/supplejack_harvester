class ChangeSizeOfBaseUrl < ActiveRecord::Migration[7.1]
  def change
    change_column :extraction_definitions, :base_url, :text
  end
end
