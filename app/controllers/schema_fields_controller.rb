class SchemaFieldsController < ApplicationController
  include LastEditedBy

  before_action :find_schema, only: %i[update destroy]
  before_action :find_schema_field, only: %i[update destroy]

  def create
    @schema_field = SchemaField.new(schema_field_params)

    if @schema_field.save
      update_last_edited_by([@schema_field.schema])
      render json: @schema_field
    else
      render500
    end
  end

  def update
    if @schema_field.update(schema_field_params)
      update_last_edited_by([@schema_field.schema])
      render json: @schema_field
    else
      render500
    end
  end

  def destroy
    if @schema_field.destroy
      update_last_edited_by([@schema_field.schema])
      render json: {}, status: :ok
    else
      render500
    end
  end

  private

  def schema_field_params
    params.require(:schema_field).permit(:name, :schema_id, :kind)
  end

  def find_schema_field
    @schema_field = @schema.schema_fields.find(params[:id])
  end

  def find_schema
    @schema = Schema.find(params[:schema_id])
  end
end
