# frozen_string_literal: true

class AddPipelineJobToHarvestJob < ActiveRecord::Migration[7.0]
  def change
    add_reference :harvest_jobs, :pipeline_job
  end
end
