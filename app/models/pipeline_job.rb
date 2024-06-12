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

  enum :page_type, { all_available_pages: 0, set_number: 1 }

  validates :key, uniqueness: true

  with_options if: :set_number? do
    validates :pages, presence: true
  end

  def enqueue_enrichment_jobs(job_id)
    return unless should_queue_enrichments?

    pipeline.enrichments.each do |enrichment|
      next unless should_queue_enrichment?(enrichment)

      enrichment_job = HarvestJob.create(
        harvest_definition: enrichment, pipeline_job: self,
        key: "#{harvest_key}__enrichment-#{enrichment.id}", target_job_id: job_id
      )

      HarvestWorker.perform_async(enrichment_job.id)
    end
  end

  def harvest_report
    harvest_reports.find_by(kind: 'harvest')
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
