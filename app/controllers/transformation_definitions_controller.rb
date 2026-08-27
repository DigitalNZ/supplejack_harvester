# frozen_string_literal: true

class TransformationDefinitionsController < ApplicationController
  include LastEditedBy
  include DefinitionActions

  before_action :find_pipeline, :find_harvest_definition
  before_action :find_transformation_definition, only: %i[show update destroy clone]
  before_action :find_extraction_jobs, only: %i[create update]
  before_action :assign_schema_variables, :assign_show_variables, only: %i[show update]

  def show; end

  def create
    create_definition('transformation')
  end

  def update
    update_definition('transformation', @transformation_definition)
  end

  def destroy
    destroy_definition('transformation', @transformation_definition)
  end

  def test
    @transformation_definition = TransformationDefinition.new(transformation_definition_params)

    render json: {
      result: @transformation_definition.records.first || [],
      format: @transformation_definition.extraction_job.extraction_definition.format
    }
  end

  def clone
    clone_definition('transformation', @transformation_definition)
  end

  private

  def assign_show_variables
    @fields = @transformation_definition.fields.order(created_at: :desc).map(&:to_h)
    @field_schema_field_values = @transformation_definition.fields.flat_map(&:field_schema_field_values).map(&:to_h)

    @props = transformation_app_state

    @extraction_jobs = @harvest_definition.available_extraction_jobs || []
  end

  def assign_schema_variables
    @schemas = Schema.order(created_at: :desc).includes(:schema_fields).map(&:to_h)

    @schema_fields = SchemaField
                     .includes(:schema_field_values,
                               fields: [:field_schema_field_values, { transformation_definition: :pipeline }])
                     .map(&:to_h)

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
                               ExtractionDefinition.enrichment.order(:name)
                             else
                               ExtractionDefinition.harvest.order(:name)
                             end

    @extraction_jobs = extraction_definitions.map do |ed|
      [ed.name, ed.extraction_jobs.not_purged.map { |job| [job.name, job.id] }]
    end
  end

  def transformation_definition_params
    safe_params = params.expect(
      transformation_definition: %i[pipeline_id content_source_id name extraction_job_id
                                    record_selector kind]
    )
    merge_last_edited_by(safe_params)
  end
end
