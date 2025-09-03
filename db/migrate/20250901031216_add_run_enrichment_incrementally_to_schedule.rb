class AddRunEnrichmentIncrementallyToSchedule < ActiveRecord::Migration[7.1]
  def change
    add_column :schedules, :skip_previously_enriched, :boolean, default: false
  end
end
