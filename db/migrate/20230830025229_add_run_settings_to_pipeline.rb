# frozen_string_literal: true

class AddRunSettingsToPipeline < ActiveRecord::Migration[7.0]
  def change
    add_column :pipeline_jobs, :page_type,         :integer, default: 0
    add_column :pipeline_jobs, :pages,             :integer
  end

  add_reference :pipeline_jobs, :destination
  add_reference :pipeline_jobs, :extraction_job
end
