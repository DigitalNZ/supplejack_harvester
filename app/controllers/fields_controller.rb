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
      render json: @field.to_h
    else
      render500
    end
  end

  def update
    if @field.update(field_params)
      schema_field_value_ids = params['field']['schema_field_value_ids'].map(&:to_i)
      schema_field_values = schema_field_value_ids.map { |id| SchemaFieldValue.find(id) }

      @field.schema_field_values = schema_field_values
      @field.save!

      update_last_edited_by([@field.transformation_definition])
      render json: @field.to_h
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
    transformation = Transformation::Execution.new([record], @fields).call.first

    render json: {
      rawRecordSlice: raw_record_slice,
      transformation:
    }
  end

  private

  def raw_record_slice
    RawRecordSlice.new(@transformation_definition, params[:page], params[:record]).call
  end

  def find_transformation_definition
    @transformation_definition = TransformationDefinition.find(params[:transformation_definition_id])
  end

  def find_fields
    @fields = @transformation_definition.fields.where(id: params['fields']).order(created_at: :desc)
  end

  def find_field
    @field = @transformation_definition.fields.find(params[:id])
  end

  def field_params
    params.require(:field).permit(:name, :block, :transformation_definition_id, :kind, :schema_field_id)
  end
end
