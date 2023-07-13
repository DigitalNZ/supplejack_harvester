# frozen_string_literal: true

class PipelinesController < ApplicationController
  before_action :assign_sort_by, only: %w[index create]
  before_action :assign_pipelines, only: %w[index]
  before_action :assign_pipeline, only: %w[show destroy edit update]

  def index
    @pipeline = Pipeline.new
  end

  def create
    @pipeline = Pipeline.new(pipeline_params)

    if @pipeline.save
      redirect_to pipeline_path(@pipeline), notice: 'Pipeline created successfully'
    else
      flash.now[:alert] = 'There was an issue creating your Pipeline'
      assign_pipelines
      render :index
    end
  end

  def show
    @harvest_extraction_definitions = ExtractionDefinition.all.harvest.sort_by(&:name).map(&:to_h)
    @harvest_transformation_definitions = TransformationDefinition.all.harvest.sort_by(&:name).map(&:to_h)

    @enrichment_extraction_definitions = ExtractionDefinition.all.enrichment.sort_by(&:name).map(&:to_h)
    @enrichment_transformation_definitions = TransformationDefinition.all.enrichment.sort_by(&:name).map(&:to_h)

    @harvest_definition = @pipeline.harvest || HarvestDefinition.new(pipeline: @pipeline)
    @harvest_job = HarvestJob.new

    @enrichment_definition = HarvestDefinition.new(pipeline: @pipeline)

    @destinations = Destination.all
  end

  def edit; end
  
  def update
    if @pipeline.update(pipeline_params)
      redirect_to pipeline_path(@pipeline), notice: 'Pipeline updated successfully'
    else
      flash.alert = 'There was an issue updating your Pipeline'
      render :edit
    end
  end

  def destroy
    if @pipeline.destroy
      redirect_to pipelines_path, notice: 'Pipeline deleted successfully'
    else
      flash.alert = 'There was an issue deleting your Pipeline'
      redirect_to pipeline_path(@pipeline)
    end
  end

  private

  def assign_pipeline
    @pipeline = Pipeline.find(params[:id])
  end

  def assign_sort_by
    @sort_by = { name: :asc }
    @sort_by = { updated_at: :desc } if params['sort_by'] == 'updated_at'
  end

  def assign_pipelines
    @pipelines = Pipeline.order(@sort_by).page(params[:page])
  end

  def pipeline_params
    params.require(:pipeline).permit(:name, :description)
  end
end
