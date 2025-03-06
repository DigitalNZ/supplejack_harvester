# frozen_string_literal: true

class AutomationStepTemplatesController < ApplicationController
  before_action :set_automation_template
  before_action :set_automation_step_template, only: [:edit, :update, :destroy]
  
  def new
    @automation_step_template = @automation_template.automation_step_templates.build(
      position: @automation_template.automation_step_templates.count
    )
    @pipelines = Pipeline.all
  end
  
  def create
    @automation_step_template = @automation_template.automation_step_templates.build(automation_step_template_params)
    
    if @automation_step_template.save
      redirect_to automation_template_path(@automation_template), notice: 'Step template was successfully added.'
    else
      @pipelines = Pipeline.all
      render :new
    end
  end
  
  def edit
    @pipelines = Pipeline.all
    @selected_pipeline = @automation_step_template.pipeline
    @harvest_definitions = @selected_pipeline.harvest_definitions if @selected_pipeline
  end
  
  def update
    if @automation_step_template.update(automation_step_template_params)
      redirect_to automation_template_path(@automation_template), notice: 'Step template was successfully updated.'
    else
      @pipelines = Pipeline.all
      @selected_pipeline = @automation_step_template.pipeline
      @harvest_definitions = @selected_pipeline.harvest_definitions if @selected_pipeline
      render :edit
    end
  end
  
  def destroy
    @automation_step_template.destroy
    
    # Reorder positions of remaining steps
    @automation_template.automation_step_templates.order(:position).each_with_index do |step, index|
      step.update_column(:position, index) if step.position != index
    end
    
    redirect_to automation_template_path(@automation_template), notice: 'Step template was successfully removed.'
  end
  
  def get_harvest_definitions
    @pipeline = Pipeline.find(params[:pipeline_id])
    @harvest_definitions = @pipeline.harvest_definitions
    
    render partial: 'harvest_definitions', locals: { harvest_definitions: @harvest_definitions }
  end
  
  private
  
  def set_automation_template
    @automation_template = AutomationTemplate.find(params[:automation_template_id])
  end
  
  def set_automation_step_template
    @automation_step_template = @automation_template.automation_step_templates.find(params[:id])
  end
  
  def automation_step_template_params
    params.require(:automation_step_template).permit(:pipeline_id, :position, harvest_definition_ids: [])
  end
end 