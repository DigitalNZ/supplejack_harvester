# frozen_string_literal: true

class AutomationSummary
  EMPTY_METRICS = {
    pages_extracted: 0,
    records_transformed: 0,
    records_loaded: 0,
    records_rejected: 0,
    records_deleted: 0
  }.freeze

  EMPTY_HARVEST_METRICS = {
    pages_extracted: 0,
    records_transformed: 0,
    records_loaded: 0,
    records_rejected: 0,
    records_deleted: 0,
    active_time: 0,
    queue_time: 0
  }.freeze

  METRIC_FIELDS = %i[
    pages_extracted
    records_transformed
    records_loaded
    records_rejected
    records_deleted
  ].freeze

  def initialize(automation)
    @automation = automation
  end

  def start_time
    @automation.created_at
  end

  def end_time
    # Get all relevant timestamps from pipeline jobs and API calls
    timestamps = []

    @automation.automation_steps.order(position: :asc).each do |step|
      if step.step_type == 'api_call'
        timestamps << step.api_response_report&.updated_at if step.api_response_report.present?
      elsif step.pipeline_job&.harvest_reports.present?
        timestamps.concat(step.pipeline_job.harvest_reports.map(&:updated_at))
      end
    end

    return nil if timestamps.empty?

    timestamps.compact.max
  end

  def total_duration
    return 0 unless end_time

    end_time - start_time
  end

  def stats
    {
      start_time: start_time,
      end_time: end_time,
      total_duration: total_duration,
      total_metrics: total_metrics,
      step_metrics: step_metrics
    }
  end

  def total_metrics
    # Initialize with empty metrics
    totals = EMPTY_METRICS.dup

    # Collect metrics from all steps with pipeline jobs
    @automation.automation_steps.each do |step|
      next if step.step_type == 'api_call' # Skip API call steps as they don't have harvest metrics
      next if step.pipeline_job.blank? || step.pipeline_job.harvest_reports.blank?

      # Add metrics from this step
      add_step_metrics_to_totals(totals, step.pipeline_job.harvest_reports)
    end

    totals
  end

  def step_metrics
    @automation.automation_steps.map do |step|
      metrics = collect_step_metrics(step)

      {
        step: step,
        metrics: metrics
      }
    end
  end

  private

  def collect_step_metrics(step)
    # For API call steps, return nil as they don't have harvest metrics
    return nil if step.step_type == 'api_call'
    return nil if step.pipeline_job.blank? || step.pipeline_job.harvest_reports.blank?

    # Initialize with empty metrics
    metrics = EMPTY_HARVEST_METRICS.dup

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
    METRIC_FIELDS.each do |field|
      metrics[field] += report.send(field).to_i
    end
  end
end
