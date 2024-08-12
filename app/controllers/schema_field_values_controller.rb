# frozen_string_literal: true

class SchemaFieldValuesController < ApplicationController
  include LastEditedBy

  before_action :find_schema, only: %i[update destroy]
  before_action :find_schema_field, only: %i[update destroy]
  before_action :find_schema_field_value, only: %i[update destroy]

  def create
    @schema_field_value = SchemaFieldValue.new(schema_field_value_params)

    if @schema_field_value.save
      update_last_edited_by([@schema_field_value.schema_field.schema])
      render json: @schema_field_value
    else
      render500
    end
  end

  def update
    if @schema_field_value.update(schema_field_value_params)
      update_last_edited_by([@schema_field_value.schema_field.schema])
      render json: @schema_field_value
    else
      render500
    end
  end

  def destroy
    if @schema_field_value.destroy
      update_last_edited_by([@schema_field_value.schema_field.schema])
      render json: {}, status: :ok
    else
      render500
    end
  end

  private

  def schema_field_value_params
    params.require(:schema_field_value).permit(:value, :schema_field_id)
  end

  def find_schema_field_value
    @schema_field_value = @schema_field.schema_field_values.find(params[:id])
  end

  def find_schema_field
    @schema_field = @schema.schema_fields.find(params[:schema_field_id])
  end

  def find_schema
    @schema = Schema.find(params[:schema_id])
  end
end
