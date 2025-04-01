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

  def harvest_report_status(report)
    report ? active_report_status(report) : default_report_status
  end

  def format_json(json_string)
    return '' if json_string.blank?

    begin
      JSON.pretty_generate(JSON.parse(json_string))
    rescue StandardError
      json_string
    end
  end

  def api_response_badge_class(api_response_report)
    if api_response_report&.status == 'completed'
      'bg-success'
    elsif ['errored', 'failed'].include?(api_response_report&.status)
      'bg-danger'
    elsif api_response_report&.status == 'queued'
      'bg-warning'
    else
      'bg-secondary'
    end
  end

  def api_response_status_text(api_response_report)
    api_response_report&.status&.humanize || 'Not started'
  end

  private

  def active_report_status(report)
    {
      badge_class: status_badge_class(report.status),
      status_text: report.status.humanize
    }
  end

  def default_report_status
    {
      badge_class: 'bg-secondary',
      status_text: 'Not started'
    }
  end
end
