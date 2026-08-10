# frozen_string_literal: true

class AddPreprocessSourceToExtractionJobs < ActiveRecord::Migration[7.2]
  def change
    # Which run's pre-processed output a standalone extraction iterates, and the block
    # position of the folder to read. A job started from a pipeline run gets both from
    # its harvest job instead, and leaves these null.
    #
    # The position is snapshotted rather than derived from the harvest definition,
    # because output folders are keyed by position on disk: reordering the blocks later
    # must not silently re-point a job that has already run.
    add_column :extraction_jobs, :source_pipeline_job_id, :bigint
    add_column :extraction_jobs, :source_position, :integer

    add_index :extraction_jobs, :source_pipeline_job_id
  end
end
