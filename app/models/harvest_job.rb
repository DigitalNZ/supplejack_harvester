# frozen_string_literal: true

# Used to store information about a Harvest Job
class HarvestJob < ApplicationRecord
  include Job

  belongs_to :pipeline_job
  belongs_to :harvest_definition
  belongs_to :extraction_job, optional: true
  has_one    :harvest_report, dependent: nil

  delegate :extraction_definition, to: :harvest_definition
  delegate :transformation_definition, to: :harvest_definition

  PROCESSES = %w[TransformationWorker LoadWorker DeleteWorker].freeze

  after_create do
    self.name = "#{id}_#{harvest_definition.kind}"
    save!
  end

  def cancel
    extraction_job.cancelled! unless extraction_job.completed?
    cancel_sidekiq_workers
    cancelled!
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
