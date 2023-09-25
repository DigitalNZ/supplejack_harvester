# frozen_string_literal: true

class RemoveRunSettingsFromHarvestJob < ActiveRecord::Migration[7.0]
  def change
    remove_column :harvest_jobs, :destination_id, :integer
    remove_column :harvest_jobs, :page_type, :integer
    remove_column :harvest_jobs, :pages, :integer
  end
end
