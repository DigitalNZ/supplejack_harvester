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
      keep_harvest_last_in_chain
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

  # Pipeline#ordered_blocks (app/models/pipeline.rb) sorts blocks by (position, id), and the
  # chain stepper relies on the harvest always being the LAST block. Preprocess blocks are
  # appended to the end of the chain on creation (position: pipeline.preprocesses.count - see
  # the "Add Pre-processing block" modal), but the harvest's own position defaults to 0 (schema
  # default, and the "Add harvest" modal sends no position field), so both creation orders can
  # break the invariant:
  #   - harvest first, preprocess added later: the harvest (position 0) ties with or trails the
  #     new preprocess blocks and the id tiebreak puts it first -> bump the existing harvest.
  #   - preprocess blocks first, harvest added later: the new harvest lands at position 0,
  #     BETWEEN or before the existing preprocess blocks -> place the new harvest at the end.
  # Both directions resolve to the same rule: the harvest-kind block must sit at (at least)
  # one position past the last preprocess block. Enforced here, on every chain-block creation,
  # instead of relying on callers to always create blocks in chain order.
  def keep_harvest_last_in_chain
    return if @harvest_definition.enrichment?

    harvest = @harvest_definition.harvest? ? @harvest_definition : @pipeline.harvest
    return if harvest.blank?

    end_of_chain_position = @pipeline.preprocesses.count
    harvest.update!(position: end_of_chain_position) if harvest.position < end_of_chain_position
  end

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
    @destinations = Destination.order(:name)
  end

  def find_harvest_definition
    @harvest_definition = HarvestDefinition.find(params[:id])
  end

  def harvest_definition_params
    params.expect(
      harvest_definition: %i[pipeline_id extraction_definition_id job_id transformation_definition_id
                             load_definition_id destination_id source_id kind position name]
    )
  end
end
