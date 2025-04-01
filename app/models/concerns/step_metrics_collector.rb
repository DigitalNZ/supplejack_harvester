# frozen_string_literal: true

# Shared functionality for collecting metrics from steps
module StepMetricsCollector
  extend ActiveSupport::Concern

  private

  def collect_step_metrics(step)
    # For API call steps, return nil as they don't have harvest metrics
    return nil if step.step_type == 'api_call'
    return nil if step.pipeline_job.blank? || step.pipeline_job.harvest_reports.blank?

    # Initialize with empty metrics
    metrics = empty_harvest_metrics

    # Aggregate metrics from all harvest reports for this step
    add_step_metrics_to_totals(metrics, step.pipeline_job.harvest_reports)

    metrics
  end

  def add_step_metrics_to_totals(totals, harvest_reports)
    harvest_reports.each do |report|
      update_metric_counts(totals, report)
    end
  end

  def update_metric_counts(metrics, report)
    metric_fields.each do |field|
      metrics[field] += report.send(field).to_i
    end
  end
end
