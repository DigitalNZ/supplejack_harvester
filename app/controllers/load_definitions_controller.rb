# frozen_string_literal: true

class LoadDefinitionsController < ApplicationController
  include LastEditedBy
  include DefinitionActions

  before_action :find_pipeline, :find_harvest_definition
  before_action :find_load_definition, only: %i[show update destroy clone]

  def show; end

  def create
    create_definition('load')
  end

  def update
    if @load_definition.update(load_definition_params)
      redirect_to pipeline_harvest_definition_load_definition_path(
        @pipeline, @harvest_definition, @load_definition
      ), notice: t('.success')
    else
      flash.alert = t('.failure')

      render :show
    end
  end

  def destroy
    if @load_definition.destroy
      redirect_to pipeline_path(@pipeline), notice: t('.success')
    else
      flash.alert = t('.failure')
      redirect_to pipeline_harvest_definition_load_definition_path(@pipeline, @harvest_definition, @load_definition)
    end
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
      load_definition: %i[pipeline_id name kind priority required_for_active_record]
    )
    merge_last_edited_by(safe_params)
  end
end
