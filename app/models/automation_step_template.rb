# frozen_string_literal: true

class AutomationStepTemplate < ApplicationRecord
  belongs_to :automation_template, touch: true
  belongs_to :pipeline, optional: true
  belongs_to :extraction_definition, optional: true

  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :pipeline_id, presence: true, if: -> { step_type == 'pipeline' }
  validates :api_url, :api_method, presence: true, if: -> { step_type == 'api_call' }
  validates :extraction_definition_id, presence: true, if: -> { step_type == 'pre_extraction' }

  serialize :harvest_definition_ids, type: Array

  API_METHODS = %w[GET POST PUT PATCH DELETE].freeze

  def harvest_definitions
    return [] unless pipeline
    return Pipeline.find(pipeline_id).harvest_definitions if harvest_definition_ids.blank?

    HarvestDefinition.where(id: harvest_definition_ids)
  end

  def display_name
    case step_type
    when 'api_call'
      "#{position + 1}. API Call: #{api_method} #{api_url}"
    when 'pre_extraction'
      "#{position + 1}. Pre-Extraction: #{extraction_definition&.name || 'Unknown'}"
    else
      "#{position + 1}. #{pipeline&.name || 'Unknown Pipeline'}"
    end
  end

  # Updates the position attribute safely
  def update_position(new_position)
    update(position: new_position)
  end
end
