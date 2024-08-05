# frozen_string_literal: true

module SchemaReduxState
  extend ActiveSupport::Concern

  def schema_redux_state
    {
      entities: schema_entities_slices,
      ui: schema_ui_slices,
      config: schema_config_slice
    }.to_json
  end

  private

  def schema_entities_slices
    {
      schemaFields: entity_slice(@schema.schema_fields),
      fieldValues: entity_slice(@schema.schema_fields.flat_map(&:schema_field_values)),
      appDetails: schema_app_details_slice
    }
  end

  def entity_slice(entities)
    {
      ids: entities.pluck(:id),
      entities: entities.map(&:to_h).index_by { |entity| entity[:id] }
    }
  end

  def schema_ui_slices
    {
      schemaFields: ui_schema_fields_slice
    }
  end

  def ui_schema_fields_slice
    schema_field_entities = @schema.schema_fields.map { |schema_field| ui_schema_field_entity(schema_field) }

    {
      ids: @schema.schema_fields.pluck(:id),
      entities: schema_field_entities.index_by { |schema_field| schema_field[:id] }
    }
  end

  def ui_schema_field_entity(schema_field)
    {
      id: schema_field[:id], saved: true,
      saving: false, deleting: false,
      active: false, displayed: true
    }
  end

  def schema_config_slice
    {
      environment: Rails.env
    }
  end

  def schema_app_details_slice
    {
      schema: @schema
    }
  end
end