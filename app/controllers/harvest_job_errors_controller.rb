# frozen_string_literal: true

class HarvestJobErrorsController < ApplicationController
  before_action :find_pipeline
  before_action :find_pipeline_job
  before_action :find_harvest_job

  def show
    @stage_errors = JobError.grouped_for_harvest_job(@harvest_job)
    @total_error_count = @stage_errors.values.sum(&:count)
    @harvest_job_path = harvest_job_path
  end

  private

  def find_pipeline
    @pipeline = Pipeline.find(params[:pipeline_id])
  end

  def find_pipeline_job
    @pipeline_job = @pipeline.pipeline_jobs.find(params[:pipeline_job_id])
  end

  def find_harvest_job
    @harvest_job = @pipeline_job.harvest_jobs.find(params[:harvest_job_id])
  end

  def harvest_job_path
    extraction_job_id = @harvest_job.extraction_job_id
    harvest_definition = @harvest_job.harvest_definition
    extraction_definition = harvest_definition&.extraction_definition
    if extraction_definition.blank? || extraction_job_id.blank?
      return pipeline_pipeline_job_path(@pipeline, @pipeline_job)
    end

    pipeline_harvest_definition_extraction_definition_extraction_job_path(
      @pipeline, harvest_definition, extraction_definition, extraction_job_id
    )
  end
end
