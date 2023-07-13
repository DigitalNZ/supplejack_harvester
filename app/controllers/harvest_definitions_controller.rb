# frozen_string_literal: true

class HarvestDefinitionsController < ApplicationController
  before_action :find_pipeline
  before_action :find_harvest_definition, only: %i[show edit update destroy]
  before_action :find_destinations

  def show
    @harvest_jobs = paginate_and_filter_jobs(@harvest_definition.harvest_jobs)
    @harvest_job = HarvestJob.new(harvest_definition: @harvest_definition)
  end

  def new
    @harvest_definition = HarvestDefinition.new(kind: params[:kind])
  end

  def edit; end

  def create
    @harvest_definition = HarvestDefinition.new(harvest_definition_params)

    if @harvest_definition.save
      redirect_to pipeline_path(@pipeline), notice: "#{@harvest_definition.kind.capitalize} created successfully"
    else
      flash.alert = "There was an issue creating your #{@harvest_definition.kind.capitalize}"
      render 'pipelines/show'
    end
  end

  def update
    if @harvest_definition.update(harvest_definition_params)
      respond_to do |format|
        format.html do
          redirect_to pipeline_path(@pipeline), notice: 'Harvest Definition updated successfully'
        end

        format.js { render status: 200, json: 'Harvest Definition update successfully' }
      end
    else
      respond_to do |format|
        format.html do 
          flash.alert = "There was an issue updating your Harvest Definition"
          redirect_to pipeline_path(@pipeline)
        end

        format.js { render status: 500, json: 'There was an issue updating your Harvest Definition' }
      end
    end
  end

  def destroy
    if @harvest_definition.destroy
      redirect_to content_source_path(@content_source), notice: 'Harvest Definition deleted successfully'
    else
      flash.alert = 'There was an issue deleting your Harvest Definition'
      redirect_to content_source_harvest_definition_path(@content_source, @harvest_definition)
    end
  end

  private

  def find_pipeline
    @pipeline = Pipeline.find(params[:pipeline_id])
  end

  def find_destinations
    @destinations = Destination.all
  end

  def find_harvest_definition
    @harvest_definition = HarvestDefinition.find(params[:id])
  end

  def harvest_definition_params
    params.require(:harvest_definition).permit(
      :pipeline_id,
      :extraction_definition_id,
      :job_id,
      :transformation_definition_id,
      :destination_id,
      :source_id,
      :priority,
      :kind,
      :required_for_active_record,
      :name
    )
  end
end
