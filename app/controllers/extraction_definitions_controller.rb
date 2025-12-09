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
      update_last_edited_by([@extraction_definition])
      @harvest_definition.update(extraction_definition_id: @extraction_definition.id)

      2.times { Request.create(extraction_definition: @extraction_definition) }

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
      :extract_text_from_file, :fragment_source_id, :fragment_key, :evaluate_javascript, :fields, :include_sub_documents,
      :pre_extraction, :pre_extraction_depth
    )

    # Force conversion to plain Ruby Hash (JSON round-trip ensures no Rails-specific objects)
    result = JSON.parse(permitted.to_json)

    # Build link_selectors from link_selector_N form fields
    result['link_selectors'] = build_link_selectors_from_params

    result
  end

  # Convert link_selector_1, link_selector_2, etc. form params into link_selectors array
  # Returns plain Ruby hashes to avoid issues with HashWithIndifferentAccess
  # :reek:FeatureEnvy - we need original_params 
  def build_link_selectors_from_params
    original_params = params[:extraction_definition]
    return [] if original_params.blank? || original_params[:pre_extraction] != 'true'

    depth = original_params[:pre_extraction_depth].to_i
    depth = 1 if depth < 1

    (1..depth).filter_map do |level|
      selector = original_params["link_selector_#{level}"]
      # Use plain Hash with string keys for clean YAML serialization
      { 'depth' => level, 'selector' => selector.to_s } if selector.present?
    end
  end
end
