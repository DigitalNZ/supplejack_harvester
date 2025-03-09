# frozen_string_literal: true

# Helper class to handle metrics calculations
class AutomationMetricsCalculator
  # Initialize metrics that we'll aggregate
  EMPTY_METRICS = {
    pages_extracted: 0,
    records_transformed: 0,
    records_loaded: 0,
    records_rejected: 0,
    records_deleted: 0
  }.freeze

  # Detailed metrics for harvest data
  EMPTY_HARVEST_METRICS = {
    pages_extracted: 0,
    records_transformed: 0,
    records_loaded: 0,
    records_rejected: 0,
    records_deleted: 0,
    active_time: 0,
    queue_time: 0
  }.freeze

  def self.aggregate_report_metrics(metrics, report)
    update_extracted_pages(metrics, report)
    update_transformed_records(metrics, report)
    update_loaded_records(metrics, report)
    update_rejected_records(metrics, report)
    update_deleted_records(metrics, report)
  end

  def self.update_extracted_pages(metrics, report)
    metrics[:pages_extracted] += report.pages_extracted.to_i
  end

  def self.update_transformed_records(metrics, report)
    metrics[:records_transformed] += report.records_transformed.to_i
  end

  def self.update_loaded_records(metrics, report)
    metrics[:records_loaded] += report.records_loaded.to_i
  end

  def self.update_rejected_records(metrics, report)
    metrics[:records_rejected] += report.records_rejected.to_i
  end

  def self.update_deleted_records(metrics, report)
    metrics[:records_deleted] += report.records_deleted.to_i
  end

  def self.update_active_time(metrics, report)
    metrics[:active_time] += report.duration_seconds.to_i if report.duration_seconds
  end

  def self.calculate_queue_time(harvest_metrics, timing_metrics)
    return unless timing_metrics[:duration].positive? && harvest_metrics[:active_time].positive?

    harvest_metrics[:queue_time] = timing_metrics[:duration] - harvest_metrics[:active_time]
    harvest_metrics[:queue_time] = 0 if harvest_metrics[:queue_time].negative?
  end
end

# Helper for finding timestamps in automation steps
class AutomationTimeHelper
  def self.find_step_start_time(step)
    earliest_time = nil

    return earliest_time unless step.pipeline_job

    job_start_time = step.pipeline_job.start_time

    earliest_time = job_start_time if earliest_time.nil? || (job_start_time && job_start_time < earliest_time)

    earliest_time
  end

  def self.find_step_end_time(step)
    latest_time = nil

    return latest_time unless step.pipeline_job

    job_end_time = step.pipeline_job.end_time

    latest_time = job_end_time if latest_time.nil? || (job_end_time && job_end_time > latest_time)

    latest_time
  end

  def self.find_earliest_pipeline_job_time(steps)
    earliest_time = nil

    steps.each do |step|
      next unless step.pipeline_job

      job_created_at = step.pipeline_job.created_at

      earliest_time = job_created_at if earliest_time.nil? || (job_created_at && job_created_at < earliest_time)
    end

    earliest_time
  end

  def self.find_latest_end_time(steps)
    latest_time = nil

    steps.each do |step|
      step_end_time = find_step_end_time(step)

      latest_time = step_end_time if latest_time.nil? || (step_end_time && step_end_time > latest_time)
    end

    latest_time
  end

  def self.calculate_timing_metrics(step_start_time, step_end_time, previous_end_time)
    metrics = {
      duration: 0,
      waiting_time: 0
    }

    metrics[:duration] = (step_end_time - step_start_time).to_i if step_start_time && step_end_time
    metrics[:waiting_time] = (step_start_time - previous_end_time).to_i if previous_end_time && step_start_time

    metrics
  end

  def self.calculate_active_duration(steps)
    total_active_duration = 0

    steps.each do |step|
      next unless step.pipeline_job&.start_time && step.pipeline_job.end_time

      active_duration = (step.pipeline_job.end_time - step.pipeline_job.start_time).to_i
      total_active_duration += active_duration
    end

    total_active_duration
  end

  def self.calculate_queue_duration(total_duration, active_duration)
    total_duration - active_duration
  end
end

# Represents a summary of metrics and statistics for an Automation
class AutomationSummary
  attr_reader :automation, :steps, :total_metrics, :step_metrics,
              :total_duration, :queue_duration, :active_duration,
              :start_time, :end_time

  def initialize(automation)
    @automation = automation
    @steps = automation.automation_steps.includes(:pipeline, pipeline_job: :harvest_reports)
    calculate_metrics
  end

  private

  def calculate_metrics
    @total_metrics = calculate_total_metrics
    @step_metrics = calculate_step_metrics
    @total_duration = calculate_total_duration
    @active_duration = AutomationTimeHelper.calculate_active_duration(steps)
    @queue_duration = AutomationTimeHelper.calculate_queue_duration(@total_duration, @active_duration)
    @start_time = find_earliest_creation_time
    @end_time = find_latest_end_time
  end

  def calculate_total_metrics
    metrics = AutomationMetricsCalculator::EMPTY_METRICS.dup

    steps.each do |step|
      next if step.pipeline_job&.harvest_reports.blank?

      aggregate_step_metrics(metrics, step)
    end

    metrics
  end

  def aggregate_step_metrics(metrics, step)
    step.pipeline_job.harvest_reports.each do |report|
      AutomationMetricsCalculator.aggregate_report_metrics(metrics, report)
    end
  end

  def calculate_step_metrics
    previous_end_time = nil
    step_metrics = []

    steps.each do |step|
      step_metrics << calculate_metrics_for_step(step, previous_end_time)
      previous_end_time = AutomationTimeHelper.find_step_end_time(step)
    end

    step_metrics
  end

  def calculate_total_duration
    start_time = find_earliest_pipeline_job_time
    end_time = find_latest_end_time

    return 0 if start_time.nil? || end_time.nil?

    (end_time - start_time).to_i
  end

  def find_earliest_creation_time
    find_earliest_pipeline_job_time
  end

  def find_earliest_pipeline_job_time
    AutomationTimeHelper.find_earliest_pipeline_job_time(steps)
  end

  def find_latest_end_time
    AutomationTimeHelper.find_latest_end_time(steps)
  end

  def calculate_metrics_for_step(step, previous_end_time)
    step_start_time = AutomationTimeHelper.find_step_start_time(step)
    step_end_time = AutomationTimeHelper.find_step_end_time(step)

    timing_metrics = AutomationTimeHelper.calculate_timing_metrics(step_start_time, step_end_time, previous_end_time)
    harvest_metrics = calculate_harvest_metrics(step, timing_metrics)

    build_step_metrics_hash(step, step_start_time, step_end_time, timing_metrics, harvest_metrics)
  end

  def build_step_metrics_hash(step, start_time, end_time, timing_metrics, harvest_metrics)
    {
      step:,
      start_time:,
      end_time:,
      waiting_time: timing_metrics[:waiting_time],
      duration: timing_metrics[:duration],
      metrics: harvest_metrics
    }
  end

  def calculate_harvest_metrics(step, timing_metrics)
    harvest_metrics = AutomationMetricsCalculator::EMPTY_HARVEST_METRICS.dup

    return harvest_metrics if step.pipeline_job&.harvest_reports.blank?

    aggregate_harvest_reports(harvest_metrics, step)
    AutomationMetricsCalculator.calculate_queue_time(harvest_metrics, timing_metrics)

    harvest_metrics
  end

  # Updates metrics from harvest reports for a step
  def aggregate_harvest_reports(metrics, step)
    step.pipeline_job.harvest_reports.each do |report|
      update_harvest_metrics_from_report(metrics, report)
    end
  end

  def update_harvest_metrics_from_report(metrics, report)
    AutomationMetricsCalculator.aggregate_report_metrics(metrics, report)
    AutomationMetricsCalculator.update_active_time(metrics, report)
  end
end
