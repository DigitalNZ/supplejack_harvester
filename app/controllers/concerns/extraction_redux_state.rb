# frozen_string_literal: true

module ExtractionReduxState
  extend ActiveSupport::Concern

  def extraction_app_state
    {
      entities: entities_slices,
      ui: ui_slices,
      config: extraction_config_slice
    }.to_json
  end

  private

  def entities_slices
    {
      requests: entity_slice(@extraction_definition.requests),
      parameters: parameters_slice,
      sharedDefinitions: entity_slice(@extraction_definition.harvest_definitions),
      appDetails: extraction_app_details_slice,
      stopConditions: entity_slice(@extraction_definition.stop_conditions.order(created_at: :desc))
    }
  end

  def entity_slice(entities)
    {
      ids: entities.pluck(:id),
      entities: entities.map(&:to_h).index_by { |entity| entity[:id] }
    }
  end

  def ui_slices
    {
      parameters: ui_parameters_slice, requests: ui_requests_slice,
      appDetails: ui_extraction_app_details_slice, stopConditions: ui_stop_conditions_slice
    }
  end

  def parameters_slice
    {
      ids: @parameters.pluck(:id),
      entities: @parameters.index_by { |request| request[:id] }
    }
  end

  def extraction_app_details_slice
    {
      pipeline: @pipeline, harvestDefinition: @harvest_definition,
      extractionDefinition: @extraction_definition
    }
  end

  def ui_extraction_app_details_slice
    {
      activeRequest: active_request_id, sharedDefinitionsTabActive: false
    }
  end

  def extraction_config_slice
    {
      environment: Rails.env
    }
  end

  def ui_parameters_slice
    # The id of the request to compare against is the same for every parameter, so it is
    # read once here rather than per parameter inside the loop.
    first_request_id = @extraction_definition.requests.first&.id
    parameter_entities = @parameters.map { |parameter| ui_parameter_entity(parameter, first_request_id) }

    {
      ids: @parameters.pluck(:id),
      entities: parameter_entities.index_by { |parameter| parameter[:id] }
    }
  end

  def ui_stop_conditions_slice
    # Ordered explicitly: #last on the relation used to order by primary key, and reading
    # the rows into an array would otherwise leave the order up to the database.
    conditions = @extraction_definition.stop_conditions.order(:id).to_a
    last_condition_id = conditions.last&.id

    stop_condition_entities = conditions.map do |condition|
      ui_stop_condition_entity(condition, last_condition_id)
    end

    {
      ids: conditions.map(&:id),
      entities: stop_condition_entities.index_by { |condition| condition[:id] }
    }
  end

  # As with the parameters above, the condition to compare against is read once and
  # compared by id, rather than re-reading the association for every condition.
  def ui_stop_condition_entity(condition, last_condition_id)
    {
      id: condition[:id], saved: true,
      saving: false, deleting: false,
      active: false, displayed: condition.id == last_condition_id
    }
  end

  # Compares request ids rather than the requests themselves: the parameter's row already
  # carries request_id, so asking it which request it belongs to costs a query per
  # parameter and loads a Request only to throw it away.
  def ui_parameter_entity(parameter, first_request_id)
    {
      id: parameter[:id], saved: true,
      saving: false, deleting: false,
      active: false, displayed: parameter.request_id == first_request_id
    }
  end

  def ui_requests_slice
    request_entities = @extraction_definition.requests.map { |request| ui_request_entity(request) }

    {
      ids: @extraction_definition.requests.pluck(:id),
      entities: request_entities.index_by { |request| request[:id] }
    }
  end

  def ui_request_entity(request)
    {
      id: request[:id], loading: false
    }
  end

  def active_request_id
    @extraction_definition.configured_request.id
  end
end
