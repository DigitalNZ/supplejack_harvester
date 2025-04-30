# frozen_string_literal: true

class HarvestWorker < ApplicationWorker
  def child_perform(harvest_job)
    @harvest_job = harvest_job
    @pipeline_job = harvest_job.pipeline_job

    @harvest_report = HarvestReport.create(pipeline_job: @pipeline_job, harvest_job: @harvest_job,
                                           kind: @harvest_job.harvest_definition.kind,
                                           definition_name: @harvest_job.harvest_definition.name)

    if @pipeline_job.extraction_job.nil? || @harvest_job.harvest_definition.enrichment?
      create_extraction_job
    else
      create_transformation_jobs
    end
  end

  def create_extraction_job
    extraction_job = ExtractionJob.create(
      extraction_definition: @harvest_job.extraction_definition,
      harvest_job: @harvest_job
    )

    ExtractionWorker.perform_async_with_priority(@pipeline_job.job_priority, extraction_job.id, @harvest_report.id)
  end

  # rubocop:disable Metrics/AbcSize
  def create_transformation_jobs
    extraction_job = @pipeline_job.extraction_job
    @harvest_job.update(extraction_job_id: extraction_job.id)
    @harvest_report.extraction_completed!

    (extraction_job.extraction_definition.page..extraction_job.documents.total_pages).each do |page|
      @harvest_report.increment_pages_extracted!
      TransformationWorker.perform_in_with_priority(@pipeline_job.job_priority, (page * 5).seconds, @harvest_job.id, page)
      @harvest_report.increment_transformation_workers_queued!

      @pipeline_job.reload
      break if @pipeline_job.cancelled? || page_number_reached?(page)
    end
  end
  # rubocop:enable Metrics/AbcSize

  private

  def page_number_reached?(page)
    @pipeline_job.set_number? && page == @pipeline_job.pages
  end
end
