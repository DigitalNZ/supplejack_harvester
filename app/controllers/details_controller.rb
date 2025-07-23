# frozen_string_literal: true

class DetailsController < ApplicationController
  before_action :find_pipeline
  before_action :find_harvest_definition
  before_action :find_extraction_definition
  before_action :find_extraction_job, only: %i[show]

  def show
    @pipeline_job = PipelineJob.find(params[:id])
    @harvest_report = @pipeline_job.harvest_report
    @harvest_reports = @pipeline.pipeline_jobs.first.harvest_reports
  end

  private

  def find_pipeline
    @pipeline = Pipeline.find(params[:pipeline_id])
  end

  def find_harvest_definition
    @harvest_definition = HarvestDefinition.find(params[:harvest_definition_id])
  end

  def find_extraction_definition
    @extraction_definition = ExtractionDefinition.find(params[:extraction_definition_id])
  end

  def find_extraction_job
    @extraction_job = @extraction_definition.extraction_jobs.find(params[:extraction_job_id])
  end
end
