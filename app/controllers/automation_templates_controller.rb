# frozen_string_literal: true

class AutomationTemplatesController < ApplicationController
  include LastEditedBy

  before_action :set_automation_template, only: [:show, :edit, :update, :destroy, :run_automation, :automations]
  
  def index
    @automation_template = AutomationTemplate.new
    @automation_templates = automation_templates
    @destinations = Destination.all
  end
  
  def show
    @step_templates = @automation_template.automation_step_templates.includes(:pipeline)
    @last_automation_run = @automation_template.automations.order(created_at: :desc).first
  end
  
  def new
    @automation_template = AutomationTemplate.new
    @destinations = Destination.all
  end
  
  def edit
    @destinations = Destination.all
  end
  
  def create
    @automation_template = AutomationTemplate.new(automation_template_params)
    
    if @automation_template.save
      redirect_to automation_templates_path, notice: 'Automation template was successfully created.'
    else
      @destinations = Destination.all
      render :new
    end
  end
  
  def update
    if @automation_template.update(automation_template_params)
      redirect_to automation_template_path(@automation_template), notice: 'Automation template was successfully updated.'
    else
      @destinations = Destination.all
      render :edit
    end
  end
  
  def destroy
    automations_count = @automation_template.automations.count
    template_name = @automation_template.name
    @automation_template.destroy
    
    if automations_count > 0
      message = "Automation template '#{template_name}' was successfully deleted along with #{automations_count} automation#{'s' if automations_count != 1}."
    else
      message = "Automation template '#{template_name}' was successfully deleted."
    end
    
    redirect_to automation_templates_path, notice: message
  end
  
  def run_automation
    automation, message, success = @automation_template.run_automation(current_user)
    if success
      redirect_to automation_template_path(@automation_template), notice: message
    else
      redirect_to automation_template_path(@automation_template), alert: message
    end
  end
  
  # Show automations created from this template
  def automations
    @automations = @automation_template.automations.page(params[:page])
  end
  
  private
  
  def set_automation_template
    @automation_template = AutomationTemplate.find(params[:id])
  end
  
  def automation_template_params
    safe_params = params.require(:automation_template).permit(:name, :description, :destination_id)
    merge_last_edited_by(safe_params)
  end

  def automation_templates
    AutomationTemplateSearchQuery.new(params).call.order(sort_by).page(params[:page])
  end

  def sort_by
    @sort_by ||= params['sort_by'] == 'name' ? { name: :asc } : { updated_at: :desc }
  end
end 