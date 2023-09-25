# frozen_string_literal: true

class AddKindToHarvestReport < ActiveRecord::Migration[7.0]
  def change
    add_column :harvest_reports, :kind, :integer, default: 0
  end
end
