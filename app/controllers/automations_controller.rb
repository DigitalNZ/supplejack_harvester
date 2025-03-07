# frozen_string_literal: true

class AutomationsController < ApplicationController
  before_action :set_automation, only: %i[show run destroy]

  def show
    @automation_summary = AutomationSummary.new(@automation)
  end

  def destroy
    @automation.destroy
    redirect_to automation_templates_path, notice: I18n.t('automations.destroy.success')
  end

  def run
    if @automation.can_run?
      @automation.run
      redirect_to automation_path(@automation), notice: I18n.t('automations.start.success')
    else
      redirect_to automation_path(@automation),
                  alert: I18n.t('automations.start.error')
    end
  end

  private

  def set_automation
    @automation = current_user.accessible_automations.find(params[:id])
  end

  def automation_params
    params.require(:automation).permit(:name, :description, :destination_id)
  end
end
