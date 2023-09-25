# frozen_string_literal: true

class RenameLoadJobsRecordsSentToApi < ActiveRecord::Migration[7.0]
  def change
    rename_column :load_jobs, :records_sent_to_api, :records_loaded
  end
end
