# frozen_string_literal: true

class AddRunEnrichmentConcurrentlyToSchedules < ActiveRecord::Migration[8.0]
  def change
    add_column :schedules, :run_enrichment_concurrently, :boolean, default: false, null: false
  end
end
