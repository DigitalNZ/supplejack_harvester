# frozen_string_literal: true

module ExtractionJobs
  # A job's retention: while it exists (retained_at is stamped) the nightly
  # extraction cleanup never deletes the job's data. POST retains, DELETE
  # stops retaining.
  class RetentionsController < ApplicationController
    before_action :find_dependencies

    def create
      if @extraction_job.purged?
        flash.alert = t('.failure')
      else
        @extraction_job.update!(retained_at: Time.zone.now)
        flash.notice = t('.success')
      end

      redirect_to job_path
    end

    def destroy
      @extraction_job.update!(retained_at: nil)
      flash.notice = t('.success')
      redirect_to job_path
    end

    private

    def find_dependencies
      @pipeline = Pipeline.find(params[:pipeline_id])
      @harvest_definition = HarvestDefinition.find(params[:harvest_definition_id])
      @extraction_definition = ExtractionDefinition.find(params[:extraction_definition_id])
      @extraction_job = @extraction_definition.extraction_jobs.find(params[:extraction_job_id])
    end

    def job_path
      pipeline_harvest_definition_extraction_definition_extraction_job_path(
        @pipeline, @harvest_definition, @extraction_definition, @extraction_job
      )
    end
  end
end
