# frozen_string_literal: true

class RawRecordsController < ApplicationController
  def index
    transformation_definition = TransformationDefinition.find(params[:transformation_definition_id])

    render json: RawRecordSlice.new(transformation_definition, params[:page], params[:record]).call
  end
end
