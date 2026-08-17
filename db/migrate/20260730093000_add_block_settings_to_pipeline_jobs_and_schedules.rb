# frozen_string_literal: true

class AddBlockSettingsToPipelineJobsAndSchedules < ActiveRecord::Migration[7.2]
  def change
    add_column :pipeline_jobs, :block_settings, :text
    add_column :schedules, :block_settings, :text
  end
end
