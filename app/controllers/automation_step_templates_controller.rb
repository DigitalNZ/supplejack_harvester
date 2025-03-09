# frozen_string_literal: true

class AutomationStepTemplatesController < ApplicationController
  before_action :set_automation_template
  before_action :set_automation_step_template, only: %i[edit update destroy]

  def new
    @automation_step_template = @automation_template.automation_step_templates.build(
      position: @automation_template.automation_step_templates.count
    )
    @pipelines = Pipeline.all
  end

  def edit
    @pipelines = Pipeline.all
    @selected_pipeline = @automation_step_template.pipeline
    @harvest_definitions = @selected_pipeline.harvest_definitions if @selected_pipeline
  end

  def create
    @automation_step_template = @automation_template.automation_step_templates.build(automation_step_template_params)

    if @automation_step_template.save
      redirect_to automation_template_path(@automation_template),
                  notice: I18n.t('automation_step_templates.create.success')
    else
      @pipelines = Pipeline.all
      render :new
    end
  end

  def update
    if @automation_step_template.update(automation_step_template_params)
      redirect_to automation_template_path(@automation_template),
                  notice: I18n.t('automation_step_templates.update.success')
    else
      @pipelines = Pipeline.all
      @selected_pipeline = @automation_step_template.pipeline
      @harvest_definitions = @selected_pipeline.harvest_definitions if @selected_pipeline
      render :edit
    end
  end

  def destroy
    position = @automation_step_template.position
    @automation_step_template.destroy

    # Reorder positions of remaining steps - update steps that were after the deleted one
    @automation_template.reload
    @automation_template.automation_step_templates.where('position > ?', position).find_each do |step|
      step.update_position(step.position - 1)
    end

    redirect_to automation_template_path(@automation_template),
                notice: I18n.t('automation_step_templates.destroy.success')
  end

  def harvest_definitions
    @pipeline = Pipeline.find(params[:pipeline_id])
    @harvest_definitions = @pipeline.harvest_definitions

    # Create a new step template if none exists (for get_harvest_definitions route)
    @automation_step_template ||= @automation_template.automation_step_templates.build

    render partial: 'harvest_definitions', locals: { harvest_definitions: @harvest_definitions }
  end

  # Alias for harvest_definitions to match the route
  alias get_harvest_definitions harvest_definitions

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
