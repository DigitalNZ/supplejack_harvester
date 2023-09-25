# frozen_string_literal: true

class AddTransformationAndLoadProcessMetricsToHarvestReport < ActiveRecord::Migration[7.0]
  def change
    add_column :harvest_reports, :transformation_workers_queued,       :integer, default: 0
    add_column :harvest_reports, :transformation_workers_completed,    :integer, default: 0

    add_column :harvest_reports, :load_workers_queued,                 :integer, default: 0
    add_column :harvest_reports, :load_workers_completed,              :integer, default: 0

    add_column :harvest_reports, :delete_workers_queued,               :integer, default: 0
    add_column :harvest_reports, :delete_workers_completed,            :integer, default: 0
  end
end
