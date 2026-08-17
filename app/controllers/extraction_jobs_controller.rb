# frozen_string_literal: true

class ExtractionJobsController < ApplicationController
  before_action :find_pipeline
  before_action :find_harvest_definition
  before_action :find_extraction_definition
  before_action :find_extraction_job, only: %i[show destroy cancel]

  def index
    @extraction_jobs = paginate_and_filter_jobs(@extraction_definition.extraction_jobs)
  end

  def show
    @documents = @extraction_job.documents
    @document = @documents[params[:page]]
  end

  def create
    respond_to do |format|
      format.html { html_create }
      format.json { json_create }
    end
  end

  def destroy
    if @extraction_job.destroy
      flash.notice = t('.success')
      redirect_to pipeline_pipeline_jobs_path(@pipeline)
    else
      flash.alert = t('.failure')
      redirect_to pipeline_harvest_definition_extraction_definition_extraction_job_path(
        @pipeline, @harvest_definition, @extraction_definition, @extraction_job
      )
    end
  end

  def cancel
    if @extraction_job.cancelled!
      flash.notice = t('.success')
    else
      flash.alert = t('.failure')
    end

    redirect_to pipeline_harvest_definition_extraction_definition_extraction_job_path(
      @pipeline, @harvest_definition, @extraction_definition, @extraction_job
    )
  end

  private

  def html_create
    return redirect_with_missing_source if preprocess_source.missing?

    @extraction_job = ExtractionJob.new(extraction_definition: @extraction_definition, kind: params[:kind],
                                        **preprocess_source.attributes)
    start_extraction_job

    redirect_to pipeline_harvest_definition_extraction_definition_extraction_jobs_path(@pipeline, @harvest_definition,
                                                                                       @extraction_definition)
  end

  def start_extraction_job
    if @extraction_job.save
      ExtractionWorker.perform_async(@extraction_job.id)
      flash.notice = t('.success')
    else
      flash.alert = t('.failure')
    end
  end

  # Which run's pre-processed records this block works from - see PreprocessSource.
  def preprocess_source
    @preprocess_source ||= PreprocessSource.new(pipeline: @pipeline, harvest_definition: @harvest_definition,
                                                nominated_run_id: params[:pipeline_job_id])
  end

  def redirect_with_missing_source
    redirect_to missing_source_location
  end

  def json_create
    return render json: { location: missing_source_location } if preprocess_source.missing?

    @extraction_job = ExtractionJob.create(extraction_definition: @extraction_definition, kind: params[:kind],
                                           **preprocess_source.attributes)
    ExtractionWorker.perform_async(@extraction_job.id)

    render json: {
      location: pipeline_harvest_definition_transformation_definition_path(@pipeline, @harvest_definition,
                                                                           create_or_update_transformation_definition)
    }
  end

  # The pipeline, with the reason in the flash. The editor redirects to whatever location
  # comes back from the JSON response, so it needs somewhere to go rather than nowhere.
  def missing_source_location
    flash[:alert] = t('.missing_preprocess_source')

    pipeline_path(@pipeline)
  end

  def create_or_update_transformation_definition
    if @harvest_definition.transformation_definition.present?
      @harvest_definition.transformation_definition.update(extraction_job_id: @extraction_job.id)
    else
      transformation_definition = TransformationDefinition.create(
        extraction_job_id: @extraction_job.id,
        pipeline_id: @pipeline.id, kind: @extraction_definition.kind
      )

      @harvest_definition.update(transformation_definition_id: transformation_definition.id)
    end

    @harvest_definition.transformation_definition
  end

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
    @extraction_job = @extraction_definition.extraction_jobs.find(params[:id])
  end
end
