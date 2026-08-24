# frozen_string_literal: true

class ParametersController < ApplicationController
  include LastEditedBy

  before_action :find_parameter, only: %i[update destroy]
  before_action :find_parameter, only: %i[update destroy]
  before_action :find_parameter, only: %i[update destroy]

  def create
    @parameter = Parameter.new(parameter_params)
    if @parameter.save
      update_last_edited_by(last_edited_by_resources)
      render json: @parameter
    else
      render422_json(@parameter)
    end
  end

  def update
    if @parameter.update(parameter_params)
      update_last_edited_by(last_edited_by_resources)
      render json: @parameter
    else
      render422_json(@parameter)
    end
  end

  def destroy
    if @parameter.destroy
      update_last_edited_by(last_edited_by_resources)
      render json: {}, status: :ok
    else
      render500
    end
  end

  private

  def last_edited_by_resources
    [@parameter.request.extraction_definition]
  end

  def find_parameter
    @parameter = Parameter.find(params[:id])
  end

  def parameter_params
    params.expect(parameter: %i[name content request_id kind content_type value_type])
  end
end
