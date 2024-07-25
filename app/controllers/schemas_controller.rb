# frozen_string_literal: true

class SchemasController < ApplicationController
  before_action :find_schema, only: %i[show destroy update]

  def index
    @schemas = Schema.order(:name).page(params[:page])
    @schema = Schema.new
  end

  def show; end

  def create
    @schema = Schema.new(schema_params)

    if @schema.save
      redirect_to schemas_path, notice: t('.success')
    else
      flash.alert = t('.failure')
      @schemas = Schema.order(:name).page(params[:page])
      render :index
    end
  end

  def destroy
    if @schema.destroy
      redirect_to schemas_path, notice: t('.success')
    else
      flash.alert = t('.failure')

      redirect_to schema_path(@schema)
    end
  end

  def update
    if @schema.update(schema_params)
      flash.notice = t('.success')

      redirect_to schemas_path
    else
      flash.alert = t('.failure')

      render 'edit'
    end
  end

  private

  def find_schema
    @schema = Schema.find(params[:id])
  end

  def schema_params
    params.require(:schema).permit(:name, :description)
  end
end