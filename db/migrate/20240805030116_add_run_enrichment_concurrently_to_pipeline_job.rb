# frozen_string_literal: true

class AddRunEnrichmentConcurrentlyToPipelineJob < ActiveRecord::Migration[7.1]
  def change
    add_column :pipeline_jobs, :run_enrichment_concurrently, :boolean, default: false, null: false
  end
end
