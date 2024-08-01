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
      fields: entity_slice(@schema.schema_fields),
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
      fields: {}
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