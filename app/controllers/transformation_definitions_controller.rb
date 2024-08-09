# frozen_string_literal: true

class TransformationDefinitionsController < ApplicationController
  include LastEditedBy

  before_action :find_pipeline
  before_action :find_harvest_definition
  before_action :find_transformation_definition, only: %i[show update destroy clone]
  before_action :find_extraction_jobs, only: %i[create update]
  before_action :assign_schema_variables, only: %i[show]
  before_action :assign_show_variables, only: %i[show update]

  def show; end

  def create
    @transformation_definition = TransformationDefinition.new(transformation_definition_params)

    if @transformation_definition.save
      @harvest_definition.update(transformation_definition_id: @transformation_definition.id)

      redirect_to pipeline_harvest_definition_transformation_definition_path(
        @pipeline, @harvest_definition, @transformation_definition
      ), notice: t('.success')
    else
      flash.alert = t('.failure')

      redirect_to pipeline_path(@pipeline)
    end
  end

  def update
    if @transformation_definition.update(transformation_definition_params)
      redirect_to pipeline_harvest_definition_transformation_definition_path(
        @pipeline, @harvest_definition, @transformation_definition
      ), notice: t('.success')
    else
      flash.alert = t('.failure')

      render :show
    end
  end

  def destroy
    if @transformation_definition.destroy
      redirect_to pipeline_path(@pipeline), notice: t('.success')
    else
      flash.alert = t('.failure')
      redirect_to pipeline_harvest_definition_transformation_definition_path(@pipeline, @harvest_definition,
                                                                             @transformation_definition)
    end
  end

  def test
    @transformation_definition = TransformationDefinition.new(transformation_definition_params)

    render json: {
      result: @transformation_definition.records.first || [],
      format: @transformation_definition.extraction_job.extraction_definition.format
    }
  end

  def clone
    clone = @transformation_definition.clone(@pipeline, transformation_definition_params['name'])

    if clone.save
      @harvest_definition.update(transformation_definition: clone)
      flash.notice = t('.success')
      redirect_to pipeline_harvest_definition_transformation_definition_path(@pipeline, @harvest_definition,
                                                                             clone)
    else
      flash.alert = t('.failure')
      redirect_to pipeline_path(@pipeline)
    end
  end

  private

  def assign_show_variables
    @fields = @transformation_definition.fields.order(created_at: :desc).map(&:to_h)
    @field_schema_field_values = @transformation_definition.fields.flat_map(&:field_schema_field_values).map(&:to_h)

    @props = transformation_app_state

    @extraction_jobs = if @harvest_definition.extraction_definition.present?
                         @harvest_definition.extraction_definition.extraction_jobs.order(created_at: :desc)
                       else
                         []
                       end
  end

  def assign_schema_variables
    @schemas = Schema.order(created_at: :desc).map(&:to_h)
    @schema_fields = SchemaField.all.map(&:to_h)
    @schema_field_values = SchemaFieldValue.all.map(&:to_h)
  end

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
    extraction_definitions = if params['kind'] == 'enrichment' || @transformation_definition&.kind == 'enrichment'
                               ExtractionDefinition.all.enrichment
                             else
                               ExtractionDefinition.all.harvest
                             end

    @extraction_jobs = extraction_definitions.map do |ed|
      [ed.name, ed.extraction_jobs.map { |job| [job.name, job.id] }]
    end
  end

  def transformation_definition_params
    safe_params = params.require(:transformation_definition).permit(
      :pipeline_id, :content_source_id, :name, :extraction_job_id,
      :record_selector, :kind
    )
    merge_last_edited_by(safe_params)
  end
end
