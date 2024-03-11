# frozen_string_literal: true

class FileExtractionWorker
  include Sidekiq::Job

  sidekiq_options retry: 0

  def perform(extraction_job_id)
    @extraction_job = ExtractionJob.find(extraction_job_id)
    @extraction_definition = @extraction_job.extraction_definition
    @extraction_folder = @extraction_job.extraction_folder
    @tmp_directory = "#{@extraction_folder}/tmp"
    @page = 1

    reset_harvest_report(harvest_report) if @extraction_job.harvest_job.present?

    setup_tmp_directory
    move_extracted_documents_into_tmp_directory
    process_extracted_documents

    FileUtils.remove_dir(@tmp_directory)

    create_transformation_jobs if @extraction_job.harvest_job.present?
  end

  private

  def create_transformation_jobs
    (@extraction_job.extraction_definition.page..@extraction_job.documents.total_pages).each do |page|
      create_transformation_job(page)
      pipeline_job.reload
      break if pipeline_job.cancelled?
    end
  end

  def harvest_report
    @extraction_job.harvest_job.harvest_report
  end

  def pipeline_job
    harvest_report.pipeline_job
  end

  def create_transformation_job(page)
    TransformationWorker.perform_async(@extraction_job.harvest_job.id, page, api_record_id(page))
    harvest_report.increment_transformation_workers_queued!
  end

  def api_record_id(page)
    return nil unless @extraction_job.extraction_definition.enrichment?

    @extraction_job.documents[page].file_path.match(/__(?<record_id>.+)__/)[:record_id]
  end

  def reset_harvest_report(harvest_report)
    harvest_report.transformation_queued!
    harvest_report.load_queued!
  end

  def setup_tmp_directory
    return if Dir.exist?(@tmp_directory)

    Dir.mkdir(@tmp_directory)
  end

  def move_extracted_documents_into_tmp_directory
    Dir.children(@extraction_folder).each do |file|
      next if file == 'tmp'

      FileUtils.move("#{@extraction_folder}/#{file}", "#{@tmp_directory}/#{file}")
    end
  end

  def process_extracted_documents
    raise 'process_extracted_documents not defined in child class'
  end

  def create_document
    raise 'create_document not defined in child class'
  end
end
