# frozen_string_literal: true

class AutomationStepsController < ApplicationController
  before_action :set_automation, only: %i[harvest_definitions get_harvest_definitions]

  def harvest_definitions
    @pipeline = Pipeline.find(params[:pipeline_id])
    @harvest_definitions = @pipeline.harvest_definitions

    render partial: 'harvest_definitions', locals: { harvest_definitions: @harvest_definitions }
  end

  # Alias for harvest_definitions to match the route
  alias get_harvest_definitions harvest_definitions

  private

  def set_automation
    @automation = current_user.accessible_automations.find(params[:automation_id])
  end
end
