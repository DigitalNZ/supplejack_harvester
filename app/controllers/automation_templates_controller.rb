# frozen_string_literal: true

class AutomationTemplatesController < ApplicationController
  include LastEditedBy

  before_action :set_automation_template_and_schedules, only: %i[show edit update destroy run_automation automations]
  before_action :set_pipeline, only: [:index], if: -> { params[:pipeline_id].present? }

  def index
    @automation_template = AutomationTemplate.new
    @automation_templates = if @pipeline
                              @pipeline.automation_templates.page(params[:page])
                            else
                              automation_templates
                            end
    @destinations = Destination.all
    @schedules = @automation_template&.automation_step_templates&.map { |a| a&.pipeline&.schedules&.all }
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
      redirect_to automation_templates_path, notice: I18n.t('automation_templates.create.success')
    else
      @destinations = Destination.all
      render :new
    end
  end

  def update
    if @automation_template.update(automation_template_params)
      redirect_to automation_template_path(@automation_template),
                  notice: I18n.t('automation_templates.update.success')
    else
      @destinations = Destination.all
      render :edit
    end
  end

  def destroy
    automations_count = @automation_template.automations.count
    template_name = @automation_template.name
    @automation_template.destroy

    message = I18n.t('automation_templates.destroy.success',
                     name: template_name,
                     count: automations_count)

    redirect_to automation_templates_path, notice: message
  end

  def run_automation
    _, message, success = @automation_template.run_automation(current_user)
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

  def set_automation_template_and_schedules
    @automation_template = AutomationTemplate.find(params[:id])
    @schedules = @automation_template&.automation_step_templates&.map { |a| a&.pipeline&.schedules&.all }
  end

  def set_pipeline
    @pipeline = Pipeline.find(params[:pipeline_id])
  end

  def automation_template_params
    safe_params = params.require(:automation_template).permit(:name, :description, :destination_id, :job_priority)
    merge_last_edited_by(safe_params)
  end

  def automation_templates
    AutomationTemplateSearchQuery.new(params).call.order(sort_by).page(params[:page])
  end

  def sort_by
    @sort_by ||= params['sort_by'] == 'name' ? { name: :asc } : { updated_at: :desc }
  end
end
