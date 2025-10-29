# frozen_string_literal: true

module PipelineJobsHelper
  def pipeline_job_transformation_input(job)
    extraction_job = job.extraction_job
    return 'New extraction' unless extraction_job

    harvest_definition = find_harvest_definition(extraction_job, job)
    extraction_definition = harvest_definition&.extraction_definition || extraction_job.extraction_definition
    return extraction_job.name unless harvest_definition && extraction_definition

    link_to extraction_job.name, pipeline_harvest_definition_extraction_definition_extraction_job_path(
      job.pipeline, harvest_definition, extraction_definition, extraction_job
    )
  end

  private

  def find_harvest_definition(extraction_job, pipeline_job)
    extraction_job.harvest_job&.harvest_definition ||
      pipeline_job.pipeline.harvest_definitions.find_by(
        extraction_definition: extraction_job.extraction_definition
      ) ||
      extraction_job.extraction_definition.harvest_definitions.first
  end
end
