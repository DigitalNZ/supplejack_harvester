# frozen_string_literal: true

class FieldsController < ApplicationController
  include LastEditedBy

  before_action :find_transformation_definition, only: %i[update destroy run]
  before_action :find_fields, only: %i[run]
  before_action :find_field, only: %i[update destroy]

  def create
    @field = Field.new(field_params)

    if @field.save
      update_last_edited_by([@field.transformation_definition])
      render json: @field
    else
      render500
    end
  end

  def update
    if @field.update(field_params)
      update_last_edited_by([@field.transformation_definition])
      render json: @field
    else
      render500
    end
  end

  def destroy
    if @field.destroy
      update_last_edited_by([@field.transformation_definition])
      render json: {}, status: :ok
    else
      render500
    end
  end

  def run
    record = @transformation_definition.records(params[:page].to_i)[params['record'].to_i - 1]

    provided_fields = @transformation_definition.fields.find(params['fields'])

    fields = provided_fields.select(&:field?)
    reject_conditions = provided_fields.select(&:reject_if?)
    delete_conditions = provided_fields.select(&:delete_if?)

    transformation = Transformation::Execution.new([record], fields, reject_conditions, delete_conditions).call.first

    render json: {
      rawRecordSlice: RawRecordSlice.new(@transformation_definition, params[:page], params[:record]).call,
      transformation:
    }
  end

  private

  def find_transformation_definition
    @transformation_definition = TransformationDefinition.find(params[:transformation_definition_id])
  end

  def find_fields
    @fields = @transformation_definition.fields.where(id: params['fields'])
  end

  def find_field
    @field = @transformation_definition.fields.find(params[:id])
  end

  def field_params
    params.require(:field).permit(:name, :block, :transformation_definition_id, :kind)
  end
end
