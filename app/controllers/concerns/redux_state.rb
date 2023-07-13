# frozen_string_literal: true

module ReduxState
  extend ActiveSupport::Concern

  def transformation_app_state
    {
      entities: {
        fields: fields_slice, rawRecord: raw_record_slice, appDetails: app_details_slice
      },
      ui: {
        fields: ui_fields_slice, appDetails: ui_app_details_slice
      },
      config: config_slice
    }.to_json
  end

  private

  def fields_slice
    {
      ids: @transformation_definition.fields.map(&:id),
      entities: @fields.index_by { |field| field[:id] }
    }
  end

  def raw_record_slice
    RawRecordSlice.new(@transformation_definition, params[:page], params[:record]).call
  end

  def app_details_slice
    {
      transformedRecord: {},
      harvestDefinition: @harvest_definition,
      pipeline: @pipeline,
      transformationDefinition: @transformation_definition
    }
  end

  def ui_fields_slice
    field_entities = @fields.map { |field| ui_field_entity(field) }
    {
      ids: @transformation_definition.fields.map(&:id),
      entities: field_entities.index_by { |field| field[:id] }
    }
  end

  def ui_field_entity(field)
    {
      id: field[:id],
      saved: true, saving: false,
      deleting: false,
      running: false,
      hasRun: false,
      expanded: true,
      displayed: false
    }
  end

  def ui_app_details_slice
    {
      fieldNavExpanded: true,
      rawRecordExpanded: true,
      transformedRecordExpanded: true,
      readOnly: @transformation_definition.copy?
    }
  end

  def config_slice
    {
      environment: Rails.env
    }
  end
end
