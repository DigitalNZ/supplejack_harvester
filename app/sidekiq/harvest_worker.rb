# frozen_string_literal: true

class HarvestWorker < ApplicationWorker
  def child_perform(harvest_job)
    @harvest_job = harvest_job
    @pipeline_job = harvest_job.pipeline_job

    @harvest_report = HarvestReport.create(pipeline_job: @pipeline_job, harvest_job: @harvest_job,
                                           kind: @harvest_job.harvest_definition.kind,
                                           definition_name: @harvest_job.harvest_definition.name)

    # Reusing an existing extraction is a per-block choice now (the Run modal's
    # "Input" column), so ask the run configuration about this block rather than
    # applying the job-wide extraction_job to every non-enrichment block.
    existing = @pipeline_job.existing_extraction_job_for(@harvest_job.harvest_definition)

    existing.nil? ? create_extraction_job : create_transformation_jobs(existing)
  end

  def create_extraction_job
    extraction_job = ExtractionJob.create(
      extraction_definition: @harvest_job.extraction_definition,
      harvest_job: @harvest_job
    )

    ExtractionWorker.perform_async_with_priority(@pipeline_job.job_priority, extraction_job.id, @harvest_report.id)
  end

  # rubocop:disable-next Metrics/AbcSize
  def create_transformation_jobs(extraction_job)
    @harvest_job.update(extraction_job_id: extraction_job.id)
    @harvest_report.extraction_completed!

    (extraction_job.extraction_definition.page..extraction_job.documents.total_pages).each do |page|
      @harvest_report.increment_pages_extracted!
      TransformationWorker.perform_in_with_priority(@pipeline_job.job_priority, (page * 5).seconds, @harvest_job.id,
                                                    page)
      @harvest_report.increment_transformation_workers_queued!

      @pipeline_job.reload
      break if @pipeline_job.cancelled? || page_number_reached?(page)
    end
  end

  private

  # nil means every available page, and never equals a page number.
  def page_number_reached?(page)
    page == @pipeline_job.pages_for(@harvest_job.harvest_definition)
  end
end
