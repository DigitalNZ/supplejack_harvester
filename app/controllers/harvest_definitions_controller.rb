# frozen_string_literal: true

class HarvestDefinitionsController < ApplicationController
  before_action :find_content_source
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
      redirect_to content_source_path(@content_source), notice: 'Harvest Definition created successfully'
    else
      flash.alert = 'There was an issue creating your Harvest Definition'
      render :new
    end
  end

  def update
    if @harvest_definition.update(harvest_definition_params.except('extraction_definition_id', 'transformation_definition_id'))

      if harvest_definition_params.include?('extraction_definition_id')
        extraction_definition = ExtractionDefinition.find(harvest_definition_params['extraction_definition_id'])
        @harvest_definition.update_extraction_definition_clone(extraction_definition)
      end

      if harvest_definition_params.include?('transformation_definition_id')
        transformation_definition = TransformationDefinition.find(harvest_definition_params['transformation_definition_id'])
        @harvest_definition.update_transformation_definition_clone(transformation_definition)
      end
      
      flash.notice = 'Harvest Definition updated successfully'
      redirect_to content_source_harvest_definition_path(@content_source, @harvest_definition)
    else
      flash.alert = 'There was an issue updating your Harvest Definition'
      render 'edit'
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

  def find_content_source
    @content_source = ContentSource.find(params[:content_source_id])
  end

  def find_destinations
    @destinations = Destination.all
  end

  def find_harvest_definition
    @harvest_definition = HarvestDefinition.find(params[:id])
  end

  def harvest_definition_params
    params.require(:harvest_definition).permit(
      :content_source_id,
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
