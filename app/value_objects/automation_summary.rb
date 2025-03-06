# frozen_string_literal: true

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
    @queue_duration = calculate_queue_duration
    @active_duration = calculate_active_duration
    @start_time = find_earliest_creation_time
    @end_time = find_latest_end_time
  end

  def calculate_total_metrics
    metrics = {
      pages_extracted: 0,
      records_transformed: 0,
      records_loaded: 0,
      records_rejected: 0,
      records_deleted: 0
    }
    
    steps.each do |step|
      next unless step.pipeline_job&.harvest_reports.present?
      
      step.pipeline_job.harvest_reports.each do |report|
        metrics[:pages_extracted] += report.pages_extracted.to_i
        metrics[:records_transformed] += report.records_transformed.to_i
        metrics[:records_loaded] += report.records_loaded.to_i
        metrics[:records_rejected] += report.records_rejected.to_i
        metrics[:records_deleted] += report.records_deleted.to_i
      end
    end
    
    metrics
  end

  def calculate_step_metrics
    previous_end_time = nil
    step_metrics = []

    steps.each do |step|
      step_metrics << calculate_metrics_for_step(step, previous_end_time)
      previous_end_time = find_step_end_time(step)
    end

    step_metrics
  end

  def calculate_total_duration
    start_time = find_earliest_pipeline_job_time
    end_time = find_latest_end_time
    
    return 0 if start_time.nil? || end_time.nil?
    
    (end_time - start_time).to_i
  end

  def calculate_active_duration
    total_active_duration = 0
    
    steps.each do |step|
      next unless step.pipeline_job&.start_time && step.pipeline_job&.end_time
      
      active_duration = (step.pipeline_job.end_time - step.pipeline_job.start_time).to_i
      total_active_duration += active_duration
    end
    
    total_active_duration
  end

  def calculate_queue_duration
    total_duration = calculate_total_duration
    active_duration = calculate_active_duration
    
    total_duration - active_duration
  end

  def find_earliest_creation_time
    find_earliest_pipeline_job_time
  end

  def find_earliest_pipeline_job_time
    earliest_time = nil
    
    steps.each do |step|
      next unless step.pipeline_job
      
      job_created_at = step.pipeline_job.created_at
      
      if earliest_time.nil? || (job_created_at && job_created_at < earliest_time)
        earliest_time = job_created_at
      end
    end
    
    earliest_time
  end

  def find_latest_end_time
    latest_time = nil
    
    steps.each do |step|
      step_end_time = find_step_end_time(step)
      
      if latest_time.nil? || (step_end_time && step_end_time > latest_time)
        latest_time = step_end_time
      end
    end
    
    latest_time
  end

  def find_step_start_time(step)
    earliest_time = nil
    
    return earliest_time unless step.pipeline_job
    
    job_start_time = step.pipeline_job.start_time
    
    if earliest_time.nil? || (job_start_time && job_start_time < earliest_time)
      earliest_time = job_start_time
    end
    
    earliest_time
  end

  def find_step_end_time(step)
    latest_time = nil
    
    return latest_time unless step.pipeline_job
    
    job_end_time = step.pipeline_job.end_time
    
    if latest_time.nil? || (job_end_time && job_end_time > latest_time)
      latest_time = job_end_time
    end
    
    latest_time
  end

  def calculate_metrics_for_step(step, previous_end_time)
    step_start_time = find_step_start_time(step)
    step_end_time = find_step_end_time(step)
    
    # Basic metrics for timing
    timing_metrics = {
      duration: 0,
      waiting_time: 0
    }
    
    if step_start_time && step_end_time
      timing_metrics[:duration] = (step_end_time - step_start_time).to_i
    end
    
    if previous_end_time && step_start_time
      timing_metrics[:waiting_time] = (step_start_time - previous_end_time).to_i
    end
    
    # Detailed metrics for harvest data
    harvest_metrics = {
      pages_extracted: 0,
      records_transformed: 0,
      records_loaded: 0,
      records_rejected: 0,
      records_deleted: 0,
      active_time: 0,
      queue_time: 0
    }
    
    if step.pipeline_job&.harvest_reports.present?
      step.pipeline_job.harvest_reports.each do |report|
        harvest_metrics[:pages_extracted] += report.pages_extracted.to_i
        harvest_metrics[:records_transformed] += report.records_transformed.to_i
        harvest_metrics[:records_loaded] += report.records_loaded.to_i
        harvest_metrics[:records_rejected] += report.records_rejected.to_i
        harvest_metrics[:records_deleted] += report.records_deleted.to_i
        harvest_metrics[:active_time] += report.duration_seconds.to_i if report.duration_seconds
      end
      
      # Calculate queue time
      if timing_metrics[:duration] > 0 && harvest_metrics[:active_time] > 0
        harvest_metrics[:queue_time] = timing_metrics[:duration] - harvest_metrics[:active_time]
        harvest_metrics[:queue_time] = 0 if harvest_metrics[:queue_time] < 0
      end
    end
    
    # Return structured data as expected by the view
    {
      step: step,
      start_time: step_start_time,
      end_time: step_end_time,
      waiting_time: timing_metrics[:waiting_time],
      duration: timing_metrics[:duration],
      metrics: harvest_metrics
    }
  end
end 