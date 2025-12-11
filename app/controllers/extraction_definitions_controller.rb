# frozen_string_literal: true

class ExtractionDefinitionsController < ApplicationController
  include LastEditedBy

  before_action :find_pipeline
  before_action :find_harvest_definition
  before_action :find_extraction_definition, only: %i[show update clone destroy]
  before_action :find_destinations, only: %i[create update]
  before_action :assign_show_variables, only: %i[show update]

  def show; end

  def create
    @extraction_definition = ExtractionDefinition.new(extraction_definition_params)

    if @extraction_definition.save
      setup_new_extraction_definition
      redirect_to pipeline_harvest_definition_extraction_definition_path(
        @pipeline, @harvest_definition, @extraction_definition
      ), notice: t('.success')
    else
      redirect_to pipeline_path(@pipeline), alert: t('.failure')
    end
  end

  def update
    if @extraction_definition.update(extraction_definition_params)
      update_last_edited_by([@extraction_definition])

      redirect_to pipeline_harvest_definition_extraction_definition_path(@pipeline, @harvest_definition,
                                                                         @extraction_definition), notice: t('.success')
    else
      flash.alert = t('.failure')

      render :show
    end
  end

  def destroy
    if @extraction_definition.destroy
      redirect_to pipeline_path(@pipeline), notice: t('.success')
    else
      flash.alert = t('.failure')

      redirect_to pipeline_harvest_definition_extraction_definition_path(@pipeline, @harvest_definition,
                                                                         @extraction_definition)
    end
  end

  def clone
    clone = @extraction_definition.clone(@pipeline, extraction_definition_params['name'])

    if clone.save
      @harvest_definition.update(extraction_definition: clone)
      redirect_to successful_clone_path(clone), notice: t('.success')
    else
      flash.alert = t('.failure')
      redirect_to pipeline_path(@pipeline)
    end
  end

  private

  def setup_new_extraction_definition
    update_last_edited_by([@extraction_definition])
    @harvest_definition.update(extraction_definition_id: @extraction_definition.id)
    2.times { Request.create(extraction_definition: @extraction_definition) }
  end

  def assign_show_variables
    @parameters = @extraction_definition.parameters.order(created_at: :desc)
    @props = extraction_app_state
    @destinations = Destination.all
  end

  def successful_clone_path(clone)
    if @harvest_definition.enrichment?
      edit_pipeline_harvest_definition_extraction_definition_path(@pipeline, @harvest_definition, clone)
    else
      pipeline_harvest_definition_extraction_definition_path(@pipeline, @harvest_definition, clone)
    end
  end

  def find_pipeline
    @pipeline = Pipeline.find(params[:pipeline_id])
  end

  def find_harvest_definition
    @harvest_definition = HarvestDefinition.find(params[:harvest_definition_id])
  end

  def find_extraction_definition
    @extraction_definition = ExtractionDefinition.find(params[:id])
  end

  def find_destinations
    @destinations = Destination.all
  end

  def extraction_definition_params
    permitted = params.require(:extraction_definition).permit(
      :pipeline_id, :name, :format, :base_url, :throttle, :page, :per_page, :follow_redirects,
      :total_selector, :kind, :destination_id, :source_id, :enrichment_url, :paginated, :split, :split_selector,
      :extract_text_from_file, :fragment_source_id, :fragment_key, :evaluate_javascript, :fields,
      :include_sub_documents,
      :pre_extraction
    )
  end
end
