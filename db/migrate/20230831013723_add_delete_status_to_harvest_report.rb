# frozen_string_literal: true

class AddDeleteStatusToHarvestReport < ActiveRecord::Migration[7.0]
  def change
    add_column :harvest_reports, :delete_status, :integer, default: 0
    add_column :harvest_reports, :delete_start_time, :timestamp
    add_column :harvest_reports, :delete_end_time, :timestamp
  end
end
