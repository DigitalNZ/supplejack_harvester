# frozen_string_literal: true

class TransformationDefinitionsController < ApplicationController
  before_action :find_content_source
  before_action :find_transformation_definition, only: %w[show edit update destroy update_harvest_definitions]
  before_action :find_extraction_jobs, only: %w[new create edit update]

  def show
    @fields = @transformation_definition.fields.map { |field| { id: field.id, name: field.name, block: field.block } }

    @related_harvest_definitions = @transformation_definition.copies.map do |copy|
      HarvestDefinition.find_by(transformation_definition_id: copy.id)
    end.compact

    @props = {
      entities: {
        fields: {
          ids: @transformation_definition.fields.map(&:id),
          entities: @fields.index_by { |field| field[:id] }
        },
        appDetails: {
          rawRecord: @transformation_definition.records.first,
          transformedRecord: {},
          contentSource: @content_source,
          transformationDefinition: @transformation_definition
        }
      },
      ui: {
        fields: {
          ids: @transformation_definition.fields.map(&:id),
          entities: @fields.map do |field|
            {
              id: field[:id],
              saved: true,
              deleting: false,
              saving: false,
              running: false,
              hasRun: false,
              displayed: false,
              expanded: true
            }
          end.index_by { |field| field[:id] }
        },
        appDetails: {
          fieldNavExpanded: true,
          rawRecordExpanded: true,
          transformedRecordExpanded: true
        }
      },
      config: {
        environment: Rails.env
      }
    }.to_json
  end

  def new
    @transformation_definition = TransformationDefinition.new(kind: params[:kind])
  end

  def edit; end

  def create
    @transformation_definition = TransformationDefinition.new(transformation_definition_params)

    if @transformation_definition.save
      redirect_to content_source_path(@content_source), notice: 'Transformation Definition created successfully'
    else
      flash.alert = 'There was an issue creating your Transformation Definition'

      render :new
    end
  end

  def update
    if @transformation_definition.update(transformation_definition_params)
      flash.notice = 'Transformation Definition updated successfully'
      redirect_to content_source_transformation_definition_path(@content_source, @transformation_definition)
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
    render json: @transformation_definition.records.first || []
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

  def find_content_source
    @content_source = ContentSource.find(params[:content_source_id])
  end

  def find_transformation_definition
    @transformation_definition = TransformationDefinition.find(params[:id])
  end

  def find_extraction_jobs
    if params['kind'] == 'enrichment'
      extraction_definitions = @content_source.extraction_definitions.enrichment.originals
    else
      extraction_definitions = @content_source.extraction_definitions.harvest.originals
    end

    @extraction_jobs = extraction_definitions.map do |ed|
      [ed.name, ed.extraction_jobs.map { |job| [job.name, job.id] }]
    end
  end

  def transformation_definition_params
    params.require(:transformation_definition).permit(
      :content_source_id,
      :name,
      :extraction_job_id,
      :record_selector,
      :kind
    )
  end
end
