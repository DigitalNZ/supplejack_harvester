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

  # Gets a formatted status for a harvest report
  # @param report [HarvestReport, nil] The harvest report
  # @return [Hash] A hash containing :badge_class and :status_text
  def harvest_report_status(report)
    report ? active_report_status(report) : default_report_status
  end

  private

  # Returns status for an active report
  # @param report [HarvestReport] The harvest report
  # @return [Hash] A hash containing :badge_class and :status_text
  def active_report_status(report)
    {
      badge_class: status_badge_class(report.status),
      status_text: report.status.humanize
    }
  end

  # Returns default status when no report exists
  # @return [Hash] A hash containing :badge_class and :status_text
  def default_report_status
    {
      badge_class: 'bg-secondary',
      status_text: 'Not started'
    }
  end
end
