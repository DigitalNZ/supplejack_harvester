# frozen_string_literal: true

# Lists the pipeline jobs that wrote preprocess output for a block, and shows
# the transformed records from one of those jobs. Read-only: output is written
# by TransformationWorker via PreProcess::Output.
class PreprocessOutputsController < ApplicationController
  before_action :find_pipeline
  before_action :find_harvest_definition

  def index
    @pipeline_jobs = @pipeline.pipeline_jobs
                              .where(id: PreProcess::Output.pipeline_job_ids_with_output(@harvest_definition.position))
                              .includes(harvest_jobs: :harvest_report)
                              .order(created_at: :desc)
                              .page(params[:page])
  end

  def show
    @pipeline_job = @pipeline.pipeline_jobs.find(params[:id])
    @documents = PreProcess::Output.new(@pipeline_job.id, @harvest_definition.position).documents
    @document = @documents[params[:page]]
  end

  private

  def find_pipeline
    @pipeline = Pipeline.find(params[:pipeline_id])
  end

  def find_harvest_definition
    @harvest_definition = HarvestDefinition.find(params[:harvest_definition_id])
  end
end
