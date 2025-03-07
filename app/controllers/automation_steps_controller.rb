# frozen_string_literal: true

class AutomationStepsController < ApplicationController
  before_action :set_automation, only: [:get_harvest_definitions]

  def get_harvest_definitions
    @pipeline = Pipeline.find(params[:pipeline_id])
    @harvest_definitions = @pipeline.harvest_definitions

    render partial: 'harvest_definitions', locals: { harvest_definitions: @harvest_definitions }
  end

  private

  def set_automation
    @automation = current_user.accessible_automations.find(params[:automation_id])
  end
end
