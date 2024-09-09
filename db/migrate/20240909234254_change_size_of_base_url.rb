# frozen_string_literal: true

class ChangeSizeOfBaseUrl < ActiveRecord::Migration[7.1]
  def up
    change_column :extraction_definitions, :base_url, :text
  end

  def down
    change_column :extraction_definitions, :base_url, :string
  end
end
