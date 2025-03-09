# frozen_string_literal: true

module AutomationTemplatesHelper
  # Finds the harvest report for a specific harvest definition in an automation run
  # @param last_automation_run [Automation] The last automation run
  # @param harvest_definition [HarvestDefinition] The harvest definition to find the report for
  # @param position [Integer] The position of the step in the automation
  # @return [HarvestReport, nil] The harvest report if found, nil otherwise
  def find_harvest_report(last_automation_run, harvest_definition, position)
    return nil unless last_automation_run

    last_automation_run
      .automation_steps
      .find_by(position: position)
      &.pipeline_job
      &.harvest_reports
      &.find do |report|
        report.harvest_job&.harvest_definition_id == harvest_definition.id
      end
  end

  # Gets a formatted status for a harvest report
  # @param report [HarvestReport, nil] The harvest report
  # @return [Hash] A hash containing :badge_class and :status_text
  def harvest_report_status(report)
    if report
      {
        badge_class: status_badge_class(report.status),
        status_text: report.status.humanize
      }
    else
      {
        badge_class: 'bg-secondary',
        status_text: 'Not started'
      }
    end
  end
end 