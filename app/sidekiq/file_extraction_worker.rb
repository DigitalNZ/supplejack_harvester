# frozen_string_literal: true

class FileExtractionWorker
  include PerformWithPriority
  include Sidekiq::Job

  sidekiq_options retry: 0

  def perform(extraction_job_id)
    initialize_instance_variables(extraction_job_id)

    reset_harvest_report(harvest_report) if @extraction_job.harvest_job.present?

    setup_tmp_directory
    move_extracted_documents_into_tmp_directory
    process_extracted_documents

    FileUtils.remove_dir(@tmp_directory)

    return if @extraction_job.harvest_job.blank?

    harvest_report.extraction_completed!
    create_transformation_jobs
  rescue StandardError => e
    log_file_extraction_error(e)
    raise
  end

  private

  def initialize_instance_variables(extraction_job_id)
    @extraction_job = ExtractionJob.find(extraction_job_id)
    @extraction_definition = @extraction_job.extraction_definition
    @extraction_folder = @extraction_job.extraction_folder
    @tmp_directory = "#{@extraction_folder}/tmp"
    @page = 1
  end

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
    TransformationWorker.perform_async_with_priority(harvest_report.pipeline_job.job_priority,
                                                     @extraction_job.harvest_job.id, page, api_record_id(page))
    harvest_report.increment_transformation_workers_queued!
  end

  def api_record_id(page)
    return nil unless @extraction_job.extraction_definition.enrichment?
    return nil if @extraction_job.documents[page].file_path.nil?

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
    Dir.children(@extraction_folder).reject { |f| f.ends_with?('tmp') }.each do |folder|
      FileUtils.move("#{@extraction_folder}/#{folder}", @tmp_directory)
    end
  end

  def process_extracted_documents
    raise 'process_extracted_documents not defined in child class'
  end

  def create_document
    raise 'create_document not defined in child class'
  end
  def folder_number(page = 1)
    (page / Extraction::Documents::DOCUMENTS_PER_FOLDER.to_f).ceil
  end

  def log_file_extraction_error(exception)
    return unless @extraction_definition&.harvest_definition&.source_id

    JobCompletionSummary.log_error(
      extraction_id: @extraction_definition.harvest_definition.source_id,
      extraction_name: @extraction_definition.harvest_definition.name,
      message: "FileExtractionWorker error: #{exception.class} - #{exception.message}",
      details: {
        worker_class: self.class.name,
        exception_class: exception.class.name,
        exception_message: exception.message,
        stack_trace: exception.backtrace&.first(20),
        extraction_job_id: @extraction_job.id,
        extraction_definition_id: @extraction_definition.id,
        harvest_job_id: @extraction_job.harvest_job&.id,
        harvest_report_id: @extraction_job.harvest_job&.harvest_report&.id,
        extraction_folder: @extraction_folder,
        tmp_directory: @tmp_directory,
        timestamp: Time.current.iso8601
      }
    )
  rescue StandardError => e
    Rails.logger.error "Failed to log file extraction error to JobCompletionSummary: #{e.message}"
  end
end