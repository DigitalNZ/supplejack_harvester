# frozen_string_literal: true

class AutomationSummary
  include StepMetricsCollector

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
    timestamps = collect_all_timestamps
    return nil if timestamps.empty?

    timestamps.compact.max
  end

  def collect_all_timestamps
    timestamps = []
    @automation.automation_steps.order(position: :asc).each do |step|
      timestamps.concat(collect_timestamps_for_step(step))
    end
    timestamps
  end

  def collect_timestamps_for_step(step)
    if step.step_type == 'api_call'
      collect_api_call_timestamps(step)
    else
      collect_pipeline_job_timestamps(step)
    end
  end

  def collect_api_call_timestamps(step)
    return [] if step.api_response_report.blank?

    [step.api_response_report&.updated_at]
  end

  def collect_pipeline_job_timestamps(step)
    return [] if step.pipeline_job&.harvest_reports.blank?

    step.pipeline_job.harvest_reports.map(&:updated_at)
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

  # These methods should be defined to be used by the StepMetricsCollector concern
  def empty_harvest_metrics
    EMPTY_HARVEST_METRICS.dup
  end

  def metric_fields
    METRIC_FIELDS
  end
end
