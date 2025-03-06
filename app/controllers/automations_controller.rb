# frozen_string_literal: true

class AutomationsController < ApplicationController
  before_action :set_automation, only: [:show, :run, :destroy]

  def show
    @steps = @automation.automation_steps.includes(:pipeline, pipeline_job: :harvest_reports)
    @total_metrics = calculate_total_metrics(@steps)
    @step_metrics = calculate_step_metrics(@steps)
    @total_duration = calculate_total_duration(@steps)
    @queue_duration = calculate_queue_duration(@steps)
    @active_duration = calculate_active_duration(@steps)
    @start_time = find_earliest_creation_time(@steps)
    @end_time = find_latest_end_time(@steps)
  end
  
  def destroy
    @automation.destroy
    redirect_to automation_templates_path, notice: 'Automation was successfully destroyed.'
  end
  
  def run
    if @automation.can_run?
      @automation.run
      redirect_to automation_path(@automation), notice: 'Automation has been started.'
    else
      redirect_to automation_path(@automation), alert: 'Cannot run automation without steps. Please add at least one step.'
    end
  end
  
  private
  
  def set_automation
    @automation = Automation.find(params[:id])
  end
  
  def automation_params
    params.require(:automation).permit(:name, :description, :destination_id)
  end
  
  def calculate_total_metrics(steps)
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
  
  def calculate_step_metrics(steps)
    previous_end_time = nil
    
    steps.map do |step|
      next { step: step, metrics: nil } unless step.pipeline_job&.harvest_reports.present?
      
      metrics = {
        pages_extracted: 0,
        records_transformed: 0,
        records_loaded: 0,
        records_rejected: 0,
        records_deleted: 0,
        duration: 0,
        active_time: 0,
        queue_time: 0
      }
      
      step.pipeline_job.harvest_reports.each do |report|
        metrics[:pages_extracted] += report.pages_extracted.to_i
        metrics[:records_transformed] += report.records_transformed.to_i
        metrics[:records_loaded] += report.records_loaded.to_i
        metrics[:records_rejected] += report.records_rejected.to_i
        metrics[:records_deleted] += report.records_deleted.to_i
        metrics[:active_time] += report.duration_seconds.to_i if report.duration_seconds
      end
      
      # Calculate duration from previous step end (or job creation if first step) to current step end
      available_start_time = previous_end_time || step.pipeline_job.created_at
      actual_start_time = find_step_start_time(step)
      end_time = find_step_end_time(step)
      
      if available_start_time && end_time
        metrics[:duration] = (end_time - available_start_time).to_i
        
        # Queue time is from when step could start until it actually started
        if actual_start_time
          metrics[:queue_time] = (actual_start_time - available_start_time).to_i
          metrics[:queue_time] = 0 if metrics[:queue_time] < 0
        end
      end
      
      # Update previous_end_time for next iteration
      previous_end_time = end_time
      
      { step: step, metrics: metrics }
    end
  end
  
  def calculate_total_duration(steps)
    start_time = find_earliest_pipeline_job_time(steps)
    end_time = find_latest_end_time(steps)
    
    return 0 unless start_time && end_time
    
    (end_time - start_time).to_i
  end
  
  def calculate_active_duration(steps)
    total_active_duration = 0
    
    steps.each do |step|
      next unless step.pipeline_job&.harvest_reports.present?
      
      step.pipeline_job.harvest_reports.each do |report|
        total_active_duration += report.duration_seconds.to_i if report.duration_seconds
      end
    end
    
    total_active_duration
  end
  
  def calculate_queue_duration(steps)
    total_duration = calculate_total_duration(steps)
    active_duration = calculate_active_duration(steps)
    
    # Queue time is all time not spent actively processing
    queue_duration = total_duration - active_duration
    queue_duration = 0 if queue_duration < 0
    
    queue_duration
  end
  
  def find_earliest_creation_time(steps)
    find_earliest_pipeline_job_time(steps)
  end
  
  def find_earliest_pipeline_job_time(steps)
    earliest_time = nil
    
    steps.each do |step|
      next unless step.pipeline_job
      
      job_created_at = step.pipeline_job.created_at
      earliest_time = job_created_at if earliest_time.nil? || (job_created_at && job_created_at < earliest_time)
    end
    
    earliest_time
  end
  
  def find_latest_end_time(steps)
    latest_time = nil
    
    steps.each do |step|
      next unless step.pipeline_job&.harvest_reports.present?
      
      step.pipeline_job.harvest_reports.each do |report|
        # Check all possible end times and use the latest one
        [report.extraction_end_time, report.transformation_end_time, 
         report.load_end_time, report.delete_end_time].compact.each do |end_time|
          latest_time = end_time if latest_time.nil? || end_time > latest_time
        end
      end
    end
    
    latest_time
  end
  
  def find_step_start_time(step)
    earliest_time = nil
    
    return nil unless step.pipeline_job&.harvest_reports.present?
    
    step.pipeline_job.harvest_reports.each do |report|
      if report.extraction_start_time
        earliest_time = report.extraction_start_time if earliest_time.nil? || report.extraction_start_time < earliest_time
      end
    end
    
    earliest_time
  end
  
  def find_step_end_time(step)
    latest_time = nil
    
    return nil unless step.pipeline_job&.harvest_reports.present?
    
    step.pipeline_job.harvest_reports.each do |report|
      # Check all possible end times and use the latest one
      [report.extraction_end_time, report.transformation_end_time, 
       report.load_end_time, report.delete_end_time].compact.each do |end_time|
        latest_time = end_time if latest_time.nil? || end_time > latest_time
      end
    end
    
    latest_time
  end
end 