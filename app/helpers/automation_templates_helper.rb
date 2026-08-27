# frozen_string_literal: true

module AutomationTemplatesHelper
  # Finds the harvest report for a specific harvest definition in an automation run
  # @param last_automation_run [Automation] The last automation run
  # @param harvest_definition [HarvestDefinition] The harvest definition to find the report for
  # @param position [Integer] The position of the step in the automation
  # @return [HarvestReport, nil] The harvest report if found, nil otherwise
  def find_harvest_report(last_automation_run, harvest_definition, position)
    return nil unless last_automation_run

    step = last_automation_run.automation_steps.find_by(position: position)
    return nil unless step&.pipeline_job

    job = step.pipeline_job
    job.harvest_reports&.find do |report|
      report.harvest_job&.harvest_definition_id == harvest_definition.id
    end
  end

  def format_json(json_string)
    return '' if json_string.blank?

    begin
      JSON.pretty_generate(JSON.parse(json_string))
    rescue StandardError
      json_string
    end
  end
end
