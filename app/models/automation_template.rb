# frozen_string_literal: true

class AutomationTemplate < ApplicationRecord
  has_many :automation_step_templates,
           -> { order(position: :asc) },
           dependent: :destroy,
           inverse_of: :automation_template
  has_many :automations, dependent: :destroy
  belongs_to :destination
  belongs_to :last_edited_by, class_name: 'User', optional: true

  validates :name, presence: true, uniqueness: true

  # Create a new Automation from this template
  # @param user [User] Optional user to set as the launcher of the automation steps
  def create_automation(user = nil)
    automation = build_automation
    return automation unless automation.save

    create_automation_steps(automation, user)
    automation
  end

  # Create and run a new automation from this template
  # @param user [User] Optional user to set as the launcher of the automation steps
  # @return [Array] Array containing [automation, status_message, success_flag]
  def run_automation(user = nil)
    if automation_running?
      return [nil, 'Cannot run automation - an automation from this template is already running', false]
    end

    automation = create_automation(user)

    return handle_automation_not_persisted unless automation.persisted?
    return handle_automation_cannot_run(automation) unless automation.can_run?

    # Run the automation
    automation.run
    [automation, 'Automation was successfully created and started', true]
  end

  def schedules
    # rubocop:disable Style/SafeNavigationChainLength
    automation_step_templates&.map { |a| a&.pipeline&.schedules&.all }&.flatten
    # rubocop:enable Style/SafeNavigationChainLength
  end

  def schedule_count
    schedules&.count
  end

  private

  def handle_automation_not_persisted
    [nil, 'Failed to create automation from template', false]
  end

  def handle_automation_cannot_run(automation)
    [automation, "Automation was created but couldn't be started - no steps defined", false]
  end

  def build_automation
    Automation.new(
      name:,
      description:,
      destination_id:,
      automation_template_id: id,
      job_priority: job_priority
    )
  end

  def create_automation_steps(automation, user)
    automation_step_templates.each do |step_template|
      automation_step = build_automation_step(automation, step_template, user)
      automation_step.save
    end
  end

  def build_automation_step(automation, step_template, user)
    automation_step = automation.automation_steps.build(
      step_type: step_template.step_type,
      pipeline_id: step_template.pipeline_id,
      position: step_template.position,
      harvest_definition_ids: step_template.harvest_definition_ids,
      launched_by: user
    )

    # Set API call specific attributes if this is an API call step
    set_api_call_attributes(automation_step, step_template) if step_template.step_type == 'api_call'

    automation_step
  end

  def set_api_call_attributes(automation_step, step_template)
    automation_step.api_url = step_template.api_url
    automation_step.api_method = step_template.api_method
    automation_step.api_headers = step_template.api_headers
    automation_step.api_body = step_template.api_body
  end

  def automation_running?
    automations.any? do |a|
      a.status != 'completed' && a.status != 'errored' && a.status != 'cancelled'
    end
  end
end
