# frozen_string_literal: true

class AddLastUpdatedTimeToHarvestReport < ActiveRecord::Migration[7.0]
  def change
    add_column :harvest_reports, :extraction_updated_time, :timestamp
    add_column :harvest_reports, :transformation_updated_time, :timestamp
    add_column :harvest_reports, :load_updated_time, :timestamp
    add_column :harvest_reports, :delete_updated_time, :timestamp
  end
end
