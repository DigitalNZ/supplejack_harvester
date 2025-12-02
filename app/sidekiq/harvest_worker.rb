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
    # Check if previous step was a pre-extraction step
    previous_pre_extraction_job_id = find_previous_pre_extraction_job_id

    extraction_job = ExtractionJob.create(
      extraction_definition: @harvest_job.extraction_definition,
      harvest_job: @harvest_job,
      pre_extraction_job_id: previous_pre_extraction_job_id,
      is_pre_extraction: false
    )

    ExtractionWorker.perform_async_with_priority(@pipeline_job.job_priority, extraction_job.id, @harvest_report.id)
  end

  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  def create_transformation_jobs
    extraction_job = @pipeline_job.extraction_job
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
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength

  private

  def page_number_reached?(page)
    @pipeline_job.set_number? && page == @pipeline_job.pages
  end

  def find_previous_pre_extraction_job_id
    unless @harvest_job.pipeline_job.automation_step
      return nil
    end

    automation = @harvest_job.pipeline_job.automation_step.automation
    current_position = @harvest_job.pipeline_job.automation_step.position

    previous_pre_extraction_step = automation.automation_steps
                                             .where('position < ?', current_position)
                                             .where(step_type: 'pre_extraction')
                                             .order(position: :desc)
                                             .first

    if previous_pre_extraction_step
      previous_pre_extraction_step.pre_extraction_job_id
    else
      nil
    end
  end
end
