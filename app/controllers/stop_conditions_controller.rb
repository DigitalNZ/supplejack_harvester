# frozen_string_literal: true

class StopConditionsController < ApplicationController
  include LastEditedBy

  before_action :find_extraction_definition, only: %i[update destroy]
  before_action :find_stop_condition, only: %i[update destroy]

  def create
    @stop_condition = StopCondition.new(stop_condition_params)

    if @stop_condition.save
      render json: @stop_condition
      update_last_edited_by([@stop_condition.extraction_definition])
    else
      render500
    end
  end

  def update
    if @stop_condition.update(stop_condition_params)
      update_last_edited_by([@stop_condition.extraction_definition])
      render json: @stop_condition
    else
      render500
    end
  end

  def destroy
    if @stop_condition.destroy
      update_last_edited_by([@stop_condition.extraction_definition])
      render json: {}, status: :ok
    else
      render500
    end
  end

  private

  def find_extraction_definition
    @extraction_definition = ExtractionDefinition.find(params[:extraction_definition_id])
  end

  def find_stop_condition
    @stop_condition = @extraction_definition.stop_conditions.find(params[:id])
  end

  def stop_condition_params
    params.expect(stop_condition: %i[name content extraction_definition_id])
  end
end
