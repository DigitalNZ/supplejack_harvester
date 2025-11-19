# frozen_string_literal: true

# Used to store information about a Harvest Job
class HarvestJob < ApplicationRecord
  include Job

  belongs_to :pipeline_job
  belongs_to :harvest_definition
  belongs_to :extraction_job, optional: true  # Old relationship (backward compatibility)
  has_many :extraction_jobs, dependent: :destroy, foreign_key: :harvest_job_id  # New relationship (for multi-item)
  has_one    :harvest_report, dependent: nil

  delegate :extraction_definition, to: :harvest_definition
  delegate :transformation_definition, to: :harvest_definition

  PROCESSES = %w[TransformationWorker LoadWorker DeleteWorker].freeze

  # This is to ensure that there is only ever one version of a HarvestJob running.
  # It is used when enqueing enrichments at the end of a harvest.
  validates :key, uniqueness: true

  after_create do
    self.name = "#{id}_#{harvest_definition.kind}"
    save!
  end

  def cancel
    # Cancel all extraction jobs (both old and new relationships)
    all_extraction_jobs.each { |ej| ej.cancelled! unless ej.completed? }
    cancel_sidekiq_workers
    cancelled!
  end

  # Returns all extraction jobs (combines old and new relationships)
  def all_extraction_jobs
    jobs = extraction_jobs.to_a  # New relationship (has_many)
    jobs << extraction_job if extraction_job.present?  # Old relationship (belongs_to)
    jobs.compact.uniq
  end

  def execute_delete_previous_records
    return unless harvest_definition.harvest?
    return unless pipeline_job.delete_previous_records? && !pipeline_job.cancelled?
    return unless harvest_report.ready_to_delete_previous_records?

    DeletePreviousRecords::Execution.new(harvest_definition.source_id, name, pipeline_job.destination).call
  end

  private

  # The order of arguments is important to sidekiq workers as they do not support keyword arguments
  # If the order of arguments change in the TransformationWorker, LoadWorker, or DeleteWorker
  # That change will need to be reflected here
  # args[0] is assumed to be the harvest_job_id

  # :reek:FeatureEnvy
  # This reek has been ignored as the job referred here is the Sidekiq job.
  def cancel_sidekiq_workers
    queue = Sidekiq::Queue.new

    queue.each do |job|
      job.delete if PROCESSES.include?(job.klass) && job.args[0] == id
    end
  end
end
