# frozen_string_literal: true

class AutomationStepTemplate < ApplicationRecord
  belongs_to :automation_template, touch: true
  belongs_to :pipeline

  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  serialize :harvest_definition_ids, type: Array

  def harvest_definitions
    HarvestDefinition.where(id: harvest_definition_ids)
  end

  def display_name
    "#{position + 1}. #{pipeline.name}"
  end
end
