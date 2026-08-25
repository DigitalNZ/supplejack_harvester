# frozen_string_literal: true

# harvest_jobs.status and extraction_jobs.status both default to 0 - queued, the first of
# the Job concern's STATUSES - and pipeline_jobs.status was the one of the three that did
# not. A run is created before the worker that starts it picks it up (ApplicationWorker
# #job_start is what sets running), so every run passes through that window, and a run whose
# worker never arrived stayed there: no status at all rather than queued, which the jobs page
# renders as an empty badge.
#
# Existing rows are deliberately left alone - they are a data question, not a schema one.
class SetDefaultStatusOnPipelineJobs < ActiveRecord::Migration[8.0]
  def change
    change_column_default :pipeline_jobs, :status, from: nil, to: 0
  end
end
