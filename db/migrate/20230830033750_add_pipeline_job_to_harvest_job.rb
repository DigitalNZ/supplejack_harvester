# frozen_string_literal: true

class AddPipelineJobToHarvestJob < ActiveRecord::Migration[7.0]
  add_reference :harvest_jobs, :pipeline_job
end
