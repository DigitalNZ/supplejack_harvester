# frozen_string_literal: true

class LoadDefinitionsController < ApplicationController
  include LastEditedBy
  include DefinitionActions

  before_action :find_pipeline, :find_harvest_definition
  before_action :find_load_definition, only: %i[show update destroy clone]

  def show; end

  # Straight back to the pipeline: unlike an extraction or a transformation, a load definition
  # is fully configured by the form that creates it, so its own page has nothing to add.
  def create
    create_definition('load', success_path: pipeline_path(@pipeline))
  end

  def update
    update_definition('load', @load_definition)
  end

  def destroy
    destroy_definition('load', @load_definition)
  end

  def clone
    clone_definition('load', @load_definition)
  end

  private

  def find_pipeline
    @pipeline = Pipeline.find(params[:pipeline_id])
  end

  def find_harvest_definition
    @harvest_definition = HarvestDefinition.find(params[:harvest_definition_id])
  end

  def find_load_definition
    @load_definition = LoadDefinition.find(params[:id])
  end

  def load_definition_params
    safe_params = params.expect(
      load_definition: %i[pipeline_id name kind priority required_for_active_record read_timeout batch_size]
    )
    merge_last_edited_by(safe_params)
  end
end
