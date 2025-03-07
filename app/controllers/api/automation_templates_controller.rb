# frozen_string_literal: true

module Api
  class AutomationTemplatesController < ApplicationController
    before_action :find_automation_template, only: [:run]

    def run
      automation, message, success = @automation_template.run_automation

      if success
        render json: { status: 'success', message:, automation_id: automation.id }
      else
        render json: { status: 'failed', message: }, status: :unprocessable_entity
      end
    end

    private

    def find_automation_template
      @automation_template = AutomationTemplate.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { status: 'failed', message: 'Automation template not found' }, status: :not_found
    end
  end
end
