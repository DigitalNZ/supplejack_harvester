# frozen_string_literal: true

class PreprocessOutputsController < ApplicationController
  before_action :find_pipeline
  before_action :find_harvest_definition

  def index
    jobs_with_output = @pipeline.pipeline_jobs.order(created_at: :desc).select do |pipeline_job|
      preprocess_output(pipeline_job).exists?
    end

    @pipeline_jobs = Kaminari.paginate_array(jobs_with_output).page(params[:page])
  end

  def show
    @pipeline_job = @pipeline.pipeline_jobs.find(params[:id])
    @documents = preprocess_output(@pipeline_job).documents
    @document = @documents[params[:page]]
  end

  private

  def preprocess_output(pipeline_job)
    PreProcess::Output.new(pipeline_job.id, @harvest_definition.position)
  end

  def find_pipeline
    @pipeline = Pipeline.find(params[:pipeline_id])
  end

  def find_harvest_definition
    @harvest_definition = HarvestDefinition.find(params[:harvest_definition_id])
  end
end
