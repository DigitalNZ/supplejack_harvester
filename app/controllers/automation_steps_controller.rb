# frozen_string_literal: true

class AutomationStepsController < ApplicationController
  before_action :set_automation, only: %i[harvest_definitions]

  def harvest_definitions
    @pipeline = Pipeline.find(params[:pipeline_id])
    @harvest_definitions = @pipeline.harvest_definitions

    # Nothing is ticked: this re-renders the list for a pipeline just chosen, before there
    # is a step to have chosen any of them.
    render partial: 'shared/harvest_definition_checkboxes',
           locals: { harvest_definitions: @harvest_definitions,
                     param_key: 'automation_step',
                     chosen: nil }
  end

  private

  def set_automation
    @automation = current_user.accessible_automations.find(params[:automation_id])
  end
end
