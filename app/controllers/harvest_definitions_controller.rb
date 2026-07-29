# frozen_string_literal: true

class HarvestDefinitionsController < ApplicationController
  include LastEditedBy

  before_action :find_pipeline
  before_action :find_harvest_definition, only: %i[update destroy]
  before_action :find_destinations

  def create
    @harvest_definition = HarvestDefinition.new(harvest_definition_params)

    harvest_kind = @harvest_definition.kind.capitalize

    if @harvest_definition.save
      update_last_edited_by([@pipeline])
      redirect_to pipeline_path(@pipeline), notice: t('.success', kind: harvest_kind)
    else
      flash.alert = t('.failure', kind: harvest_kind)

      redirect_to pipeline_path(@pipeline)
    end
  end

  def update
    respond_to do |format|
      format.html { html_update }
      format.json { json_update }
    end
  end

  def destroy
    harvest_kind = @harvest_definition.kind.capitalize

    if @harvest_definition.destroy
      update_last_edited_by([@pipeline])
      flash.notice = t('.success', kind: harvest_kind)
    else
      flash.alert = t('.failure', kind: harvest_kind)
    end

    redirect_to pipeline_path(@pipeline)
  end

  private

  def html_update
    if @harvest_definition.update(harvest_definition_params)
      update_last_edited_by([@pipeline])
      flash.notice = t('.success')
    else
      flash.alert = t('.failure')
    end

    redirect_to pipeline_path(@pipeline)
  end

  def json_update
    if @harvest_definition.update(harvest_definition_params)
      render status: :ok, json: t('.success')
    else
      render status: :internal_server_error, json: t('.failure')
    end
  end

  def find_pipeline
    @pipeline = Pipeline.find(params[:pipeline_id])
  end

  def find_destinations
    @destinations = Destination.all
  end

  def find_harvest_definition
    @harvest_definition = HarvestDefinition.find(params[:id])
  end

  def harvest_definition_params
    params.expect(
      harvest_definition: %i[pipeline_id extraction_definition_id job_id transformation_definition_id destination_id
                             source_id priority kind required_for_active_record name]
    )
  end
end
