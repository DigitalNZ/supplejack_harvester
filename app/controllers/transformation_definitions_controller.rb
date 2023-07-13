# frozen_string_literal: true

class TransformationDefinitionsController < ApplicationController
  before_action :find_pipeline
  before_action :find_harvest_definition
  before_action :find_transformation_definition, only: %w[show edit update destroy update_harvest_definitions]
  before_action :find_extraction_jobs, only: %w[new create edit update]

  def show
    @fields = @transformation_definition.fields.map { |field| { id: field.id, name: field.name, block: field.block } }

    @related_harvest_definitions = @transformation_definition.copies.map do |copy|
      HarvestDefinition.find_by(transformation_definition_id: copy.id)
    end.compact

    @props = transformation_app_state
  end

  def new
    @transformation_definition = TransformationDefinition.new(kind: params[:kind])
  end

  def edit; end

  def create
    @transformation_definition = TransformationDefinition.new(transformation_definition_params)

    if @transformation_definition.save

      if params[:harvest_definition_id].present?
        HarvestDefinition.find(params[:harvest_definition_id]).update(
          transformation_definition_id: @transformation_definition.id
        )
      end

      redirect_to pipeline_path(@pipeline), notice: 'Transformation Definition created successfully'
    else
      flash.alert = 'There was an issue creating your Transformation Definition'

      render :new
    end
  end

  def update
    if @transformation_definition.update(transformation_definition_params)
      flash.notice = 'Transformation Definition updated successfully'
      redirect_to pipeline_harvest_definition_transformation_definition_path(@pipeline, @harvest_definition, @transformation_definition)
    else
      flash.alert = 'There was an issue updating your Transformation Definition'
      render 'edit'
    end
  end

  def destroy
    if @transformation_definition.destroy
      redirect_to content_source_path(@content_source), notice: 'Transformation Definition deleted successfully'
    else
      flash.alert = 'There was an issue deleting your Transformation Definition'
      redirect_to content_source_transformation_definition_path(@content_source, @transformation_definition)
    end
  end

  def test
    @transformation_definition = TransformationDefinition.new(transformation_definition_params)
    render json: {
      result: (@transformation_definition.records.first || []),
      format: @transformation_definition.extraction_job.extraction_definition.format
    }
  end

  def update_harvest_definitions
    @transformation_definition.copies.each do |copy|
      harvest_definition = HarvestDefinition.find_by(transformation_definition: copy)
      next if harvest_definition.nil?

      harvest_definition.update_transformation_definition_clone(@transformation_definition)
    end

    flash.notice = 'Harvest definitions updated.'
    redirect_to content_source_transformation_definition_path(@content_source, @transformation_definition)
  end

  private

  def find_pipeline
    @pipeline = Pipeline.find(params[:pipeline_id])
  end
  
  def find_harvest_definition
    @harvest_definition = HarvestDefinition.find(params[:harvest_definition_id])
  end

  def find_transformation_definition
    @transformation_definition = TransformationDefinition.find(params[:id])
  end

  def find_extraction_jobs
    if params['kind'] == 'enrichment' || @transformation_definition&.kind == 'enrichment'
      extraction_definitions = ExtractionDefinition.all.enrichment
    else
      extraction_definitions = ExtractionDefinition.all.harvest
    end

    @extraction_jobs = extraction_definitions.map do |ed|
      [ed.name, ed.extraction_jobs.map { |job| [job.name, job.id] }]
    end
  end

  def transformation_definition_params
    params.require(:transformation_definition).permit(
      :pipeline_id,
      :content_source_id,
      :name,
      :extraction_job_id,
      :record_selector,
      :kind
    )
  end
end
