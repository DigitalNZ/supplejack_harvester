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

  # Recursively convert HashWithIndifferentAccess to plain hash for YAML serialization
  def to_plain_hash(obj)
    case obj
    when Hash, ActiveSupport::HashWithIndifferentAccess
      obj.each_with_object({}) do |(key, value), result|
        result[key.to_s] = to_plain_hash(value)
      end
    when Array
      obj.map { |item| to_plain_hash(item) }
    else
      obj
    end
  end

  def extraction_definition_params
    safe_params = params.require(:extraction_definition).permit(
      :pipeline_id, :name, :format, :base_url, :throttle, :page, :per_page, :follow_redirects,
      :total_selector, :kind, :destination_id, :source_id, :enrichment_url, :paginated, :split, :split_selector,
      :extract_text_from_file, :fragment_source_id, :fragment_key, :evaluate_javascript, :fields, :include_sub_documents,
      :pre_extraction, :pre_extraction_depth,
      link_selectors: [:depth, :selector]
    )
    
    # Convert link_selector_N parameters to link_selectors array
    # Extract raw params to avoid HashWithIndifferentAccess serialization issues
    raw_params = params[:extraction_definition] || {}
    
    if safe_params[:pre_extraction] == 'true' && raw_params.present?
      link_selectors_array = []
      depth = safe_params[:pre_extraction_depth].to_i
      depth = 1 if depth < 1
      
      (1..depth).each do |level|
        selector_key = "link_selector_#{level}"
        # Access raw params directly to get plain string values
        selector_value = raw_params[selector_key] || raw_params[selector_key.to_sym]
        if selector_value.present?
          # Create plain Ruby hash with string keys for YAML serialization
          # Must use plain Hash, not HashWithIndifferentAccess
          plain_hash = { 'depth' => level.to_i, 'selector' => selector_value.to_s }
          link_selectors_array << plain_hash
        end
      end
      
      # Assign plain array of plain hashes
      safe_params[:link_selectors] = link_selectors_array
    elsif safe_params[:pre_extraction] == 'false'
      # Clear link_selectors if pre_extraction is disabled
      safe_params[:link_selectors] = []
    end
    
    # Convert to plain hash to avoid HashWithIndifferentAccess serialization issues
    # This ensures all nested structures are plain Ruby objects
    final_params = to_plain_hash(safe_params.to_h)
    
    # Remove link_selector if it exists (shouldn't, but just in case)
    final_params.delete('link_selector')
    
    # Ensure link_selectors array contains only plain hashes
    if final_params['link_selectors'].present?
      final_params['link_selectors'] = final_params['link_selectors'].map do |entry|
        if entry.is_a?(Hash)
          # Create a new plain hash to avoid any HashWithIndifferentAccess contamination
          { 'depth' => entry['depth']&.to_i, 'selector' => entry['selector']&.to_s }
        else
          entry
        end
      end.reject { |e| e.nil? || e['depth'].nil? || e['selector'].nil? }
    end
    
    # Add last_edited_by_id directly to the hash (avoid Parameters conversion issues)
    final_params['last_edited_by_id'] = current_user.id if current_user.present?
    
    # Return plain hash with string keys for serialization
    # This ensures no HashWithIndifferentAccess objects remain
    final_params
  end
end
