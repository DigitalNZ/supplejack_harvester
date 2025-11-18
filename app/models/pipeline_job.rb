# frozen_string_literal: true

class PipelineJob < ApplicationRecord
  include Job

  serialize :harvest_definitions_to_run, type: Array

  belongs_to :pipeline
  belongs_to :extraction_job, optional: true
  belongs_to :destination
  belongs_to :schedule, optional: true
  belongs_to :launched_by, class_name: 'User', optional: true

  has_many :harvest_reports, dependent: :destroy
  has_many :harvest_jobs, dependent: :destroy
  belongs_to :automation_step, optional: true

  enum :page_type, { all_available_pages: 0, set_number: 1 }

  validates :key, uniqueness: true

  with_options if: :set_number? do
    validates :pages, presence: true
  end

  # Check if this job is part of an automation
  def from_automation?
    automation_step.present?
  end

  # Trigger the next step in the automation if this job is from an automation and has completed
  def trigger_next_automation_step
    return unless from_automation? && harvest_reports.all?(&:completed?)

    # Find the current step and the next step in the automation
    current_step = automation_step
    next_step = current_step.next_step

    # If there's a next step, continue the automation
    return if next_step.blank?

    AutomationWorker.perform_async_with_priority(job_priority, current_step.automation_id, next_step.id)
  end

  def enqueue_enrichment_jobs(job_id)
    return unless should_queue_enrichments?

    pipeline.enrichments.each do |enrichment|
      next unless should_queue_enrichment?(enrichment)

      enrichment_job = HarvestJob.create(
        harvest_definition: enrichment, pipeline_job: self,
        key: "#{harvest_key}__enrichment-#{enrichment.id}", target_job_id: job_id
      )

      HarvestWorker.perform_async_with_priority(job_priority, enrichment_job.id)
    end
  end

  def harvest_report
    harvest_reports.find_by(kind: 'harvest')
  end

  # Find the source extraction job from a previous automation step for link extraction
  # Returns the extraction job from the previous step, or nil if not found
  def source_extraction_job_for_link_extraction(extraction_definition)
    Rails.logger.info "[LinkExtraction] Finding source extraction job for pipeline_job #{id}"
    
    unless from_automation?
      Rails.logger.warn "[LinkExtraction] Pipeline job #{id} is not from an automation"
      return nil
    end
    
    unless automation_step.present?
      Rails.logger.warn "[LinkExtraction] Pipeline job #{id} has no automation_step"
      return nil
    end

    Rails.logger.info "[LinkExtraction] Current automation step: #{automation_step.id}, position: #{automation_step.position}"
    
    # Determine which step to use as source
    source_step_position = extraction_definition.source_automation_step_position
    Rails.logger.info "[LinkExtraction] Source step position specified: #{source_step_position.inspect}"
    
    source_step = if source_step_position.present?
                    # Use specified step position
                    Rails.logger.info "[LinkExtraction] Looking for step at position #{source_step_position}"
                    automation_step.automation.automation_steps.find_by(position: source_step_position)
                  else
                    # Default to previous step
                    Rails.logger.info "[LinkExtraction] Looking for previous step (position < #{automation_step.position})"
                    automation_step.automation.automation_steps
                                   .where('position < ?', automation_step.position)
                                   .order(position: :desc)
                                   .first
                  end

    if source_step.blank?
      Rails.logger.warn "[LinkExtraction] No source step found"
      return nil
    end
    
    Rails.logger.info "[LinkExtraction] Found source step: #{source_step.id}, position: #{source_step.position}"
    
    unless source_step.pipeline_job.present?
      Rails.logger.warn "[LinkExtraction] Source step #{source_step.id} has no pipeline_job"
      return nil
    end

    Rails.logger.info "[LinkExtraction] Source step pipeline_job: #{source_step.pipeline_job.id}"

    # Get the first harvest job's extraction job from the source step
    source_harvest_job = source_step.pipeline_job.harvest_jobs.first
    if source_harvest_job.blank?
      Rails.logger.warn "[LinkExtraction] Source step pipeline_job has no harvest_jobs"
      return nil
    end

    Rails.logger.info "[LinkExtraction] Source harvest_job: #{source_harvest_job.id}"
    
    source_extraction_job = source_harvest_job.extraction_job
    if source_extraction_job.blank?
      Rails.logger.warn "[LinkExtraction] Source harvest_job has no extraction_job"
      return nil
    end

    Rails.logger.info "[LinkExtraction] Found source extraction_job: #{source_extraction_job.id}, status: #{source_extraction_job.status}"
    source_extraction_job
  end

  private

  def should_queue_enrichments?
    reload
    !cancelled? && pipeline.enrichments.present? && harvest_completed?
  end

  def should_queue_enrichment?(enrichment)
    should_run?(enrichment.id) &&
      enrichment.ready_to_run? &&
      HarvestJob.find_by(key: "#{harvest_key}__enrichment-#{enrichment.id}").blank?
  end

  def harvest_completed?
    return true if harvest_report.blank?

    harvest_report.completed?
  end

  def should_run?(id)
    harvest_definitions_to_run.map(&:to_i).include?(id)
  end

  def harvest_key
    return key unless key.include?('__')

    key.match(/(?<key>.+)__/)[:key]
  end
end
