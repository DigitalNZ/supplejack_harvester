# frozen_string_literal: true

class ExtractionJobsController < ApplicationController
  before_action :find_pipeline, only: %i[show create destroy cancel]
  before_action :find_harvest_definition
  before_action :find_extraction_definition, only: %i[show create destroy cancel]
  before_action :find_extraction_job, only: %i[show destroy cancel]

  def index
    @extraction_jobs = paginate_and_filter_jobs(ExtractionJob)
  end

  def show
    @documents = @extraction_job.documents
    @document = @documents[params[:page]]
  end

  def create
    @extraction_job = ExtractionJob.new(extraction_definition: @extraction_definition, kind: params[:kind])

    if @extraction_job.save
      ExtractionWorker.perform_async(@extraction_job.id)
      flash.notice = 'Job queued successfuly'
    else
      flash.alert = 'There was an issue launching the job'
    end

    redirect_to pipeline_jobs_path(@pipeline)
  end

  def destroy
    if @extraction_job.destroy
      flash.notice = 'Results deleted successfully'
      redirect_to pipeline_harvest_definition_extraction_definition_path(@pipeline, @harvest_definition, @extraction_definition)
    else
      flash.alert = 'There was an issue deleting the results'
      redirect_to pipeline_harvest_definition_extraction_definition_extraction_job_path(@pipeline, @harvest_definition, @extraction_definition,
                                                                            @extraction_job)
    end
  end

  def cancel
    if @extraction_job.cancelled!
      flash.notice = 'Job cancelled successfully'
    else
      flash.alert = 'There was an issue cancelling the job'
    end

    redirect_to pipeline_jobs_path(@pipeline)
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
    @extraction_job = ExtractionJob.find(params[:id])
  end
end
