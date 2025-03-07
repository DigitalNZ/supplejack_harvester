# frozen_string_literal: true

class AutomationTemplate < ApplicationRecord
  has_many :automation_step_templates, -> { order(position: :asc) }, dependent: :destroy
  has_many :automations, dependent: :destroy
  belongs_to :destination
  belongs_to :last_edited_by, class_name: 'User', optional: true

  validates :name, presence: true, uniqueness: true

  # Create a new Automation from this template
  # @param user [User] Optional user to set as the launcher of the automation steps
  def create_automation(user = nil)
    automation = Automation.new(
      name:,
      description:,
      destination_id:,
      automation_template_id: id
    )

    if automation.save
      # Create automation steps from the template steps
      automation_step_templates.each do |step_template|
        automation_step = automation.automation_steps.build(
          pipeline_id: step_template.pipeline_id,
          position: step_template.position,
          harvest_definition_ids: step_template.harvest_definition_ids,
          launched_by: user
        )
        automation_step.save
      end
    end

    automation
  end

  # Create and run a new automation from this template
  # @param user [User] Optional user to set as the launcher of the automation steps
  # @return [Array] Array containing [automation, status_message, success_flag]
  def run_automation(user = nil)
    running_automations = automations.select do |a|
      a.status != 'completed' && a.status != 'failed' && a.status != 'cancelled'
    end

    if running_automations.any?
      return [nil, 'Cannot run automation - an automation from this template is already running', false]
    end

    # Create the automation
    automation = create_automation(user)

    return [nil, 'Failed to create automation from template', false] unless automation.persisted?
    # Run the automation if it has steps
    unless automation.can_run?
      return [automation, "Automation was created but couldn't be started - no steps defined", false]
    end

    automation.run
    [automation, 'Automation was successfully created and started', true]
  end
end
