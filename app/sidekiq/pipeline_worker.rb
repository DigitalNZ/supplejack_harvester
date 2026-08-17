# frozen_string_literal: true

class PipelineWorker < ApplicationWorker
  def child_perform(pipeline_job)
    @pipeline_job = pipeline_job
    @pipeline = pipeline_job.pipeline

    if running_the_chain?
      start_chain
    else
      start_definitions
    end
  end

  # avoids the ApplicationWorker job_end updating the job status to completed
  def job_end; end

  private

  # We are running the processing chain when any of its blocks (the preprocess and
  # harvest definitions, in position order) is included in this run. Only the first
  # selected block is started here; the chain steps itself forward on completion via
  # PipelineJob#advance_to_next_block. Otherwise (an enrichment-only run) we fall
  # back to the legacy behaviour of starting the requested definitions.
  #
  # The first selected block is not necessarily the first block of the pipeline: a
  # run that reuses earlier pre-processed data starts part-way down the chain, and
  # that block's input tells it which run's output to read (PipelineJob#preprocess_source_job_id).
  def running_the_chain?
    first_selected_block.present?
  end

  def start_chain
    job = HarvestJob.create(pipeline_job: @pipeline_job, harvest_definition: first_selected_block)
    HarvestWorker.perform_async_with_priority(@pipeline_job.job_priority, job.id)
  end

  def start_definitions
    @pipeline_job.harvest_definitions_to_run.each do |harvest_definition|
      definition = HarvestDefinition.find(harvest_definition)

      job = HarvestJob.create(pipeline_job: @pipeline_job, harvest_definition: definition)

      HarvestWorker.perform_async_with_priority(@pipeline_job.job_priority, job.id)

      # If the user has scheduled a harvest we do not need to enqueue the enrichments now
      # as they will be enqueued once the harvest job has finished.
      break if definition.harvest?
    end
  end

  def first_selected_block
    @first_selected_block ||= @pipeline.ordered_blocks.find { |block| definitions_to_run.include?(block.id) }
  end

  def definitions_to_run
    @pipeline_job.harvest_definitions_to_run.map(&:to_i)
  end
end
