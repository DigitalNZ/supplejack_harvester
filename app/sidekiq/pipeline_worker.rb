# frozen_string_literal: true

class PipelineWorker < ApplicationWorker
  def child_perform(pipeline_job)
    @pipeline_job = pipeline_job
    @pipeline = pipeline_job.pipeline

    @pipeline_job.harvest_definitions_to_run.each do |harvest_definition|
      definition = HarvestDefinition.find(harvest_definition)

      key = @pipeline_job.key
      key = "#{key}__enrichment-#{definition.id}" if definition.enrichment?

      job = HarvestJob.create(pipeline_job: @pipeline_job, harvest_definition: definition, key:)

      HarvestWorker.perform_async(job.id)

      # If the user has scheduled a harvest we do not need to enqueue the enrichments now
      # as they will be enqueued once the harvest job has finished.
      break if definition.harvest?
    end
  end
end
