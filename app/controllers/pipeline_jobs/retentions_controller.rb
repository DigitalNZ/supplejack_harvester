# frozen_string_literal: true

module PipelineJobs
  # A run's retention: while it exists (retained_at is stamped) the nightly
  # preprocess sweep never deletes the run's output folder. POST retains,
  # DELETE stops retaining. Answers JSON: the caller is the preprocess
  # preview modal.
  class RetentionsController < ApplicationController
    before_action :find_pipeline_job

    def create
      @pipeline_job.update!(retained_at: Time.zone.now)
      render json: { retained: true }
    end

    def destroy
      @pipeline_job.update!(retained_at: nil)
      render json: { retained: false }
    end

    private

    def find_pipeline_job
      @pipeline_job = Pipeline.find(params[:pipeline_id]).pipeline_jobs.find(params[:pipeline_job_id])
    end
  end
end
