# frozen_string_literal: true

class FieldSchemaFieldValuesController < ApplicationController
  before_action :find_field_schema_field_value, only: %i[update destroy]

  def create
    @field_schema_field_value = FieldSchemaFieldValue.new(field_schema_field_value_params)

    if @field_schema_field_value.save
      render json: @field_schema_field_value
    else
      render500
    end
  end

  def update
    if @field_schema_field_value.update(field_schema_field_value_params)
      render json: @field.to_h
    else
      render500
    end
  end

  def destroy
    if @field_schema_field_value.destroy
      render json: {}, status: :ok
    else
      render500
    end
  end

  private

  def field_schema_field_value_params
    params.require(:field_schema_field_value).permit(:field_id, :schema_field_value_id)
  end

  def find_field_schema_field_value
    @field_schema_field_value = FieldSchemaFieldValue.find(params[:id])
  end
end