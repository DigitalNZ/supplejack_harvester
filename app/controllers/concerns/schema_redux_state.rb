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
      fields: {}
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
end