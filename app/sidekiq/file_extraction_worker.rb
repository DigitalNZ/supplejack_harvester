# frozen_string_literal: true

class FileExtractionWorker
  include PerformWithPriority
  include Sidekiq::Job

  sidekiq_options retry: 0

  def perform(extraction_job_id)
    initialize_instance_variables(extraction_job_id)

    reset_harvest_report if harvest_job

    prepare_tmp_directory
    move_documents_to_tmp_directory
    ensure_process_method_implemented
    process_extracted_documents

    FileUtils.remove_dir(@tmp_directory)

    return unless harvest_job

    harvest_report.extraction_completed!
    create_transformation_jobs
  end

  private

  def initialize_instance_variables(extraction_job_id)
    @extraction_job = ExtractionJob.find(extraction_job_id)
    @extraction_definition = @extraction_job.extraction_definition
    @extraction_folder = @extraction_job.extraction_folder
    @tmp_directory = File.join(@extraction_folder, 'tmp')
    @page = 1
  end

  def harvest_job
    @extraction_job.harvest_job
  end

  def harvest_report
    @harvest_report ||= harvest_job&.harvest_report
  end

  def pipeline_job
    @pipeline_job ||= harvest_report&.pipeline_job
  end

  def reset_harvest_report
    harvest_report.transformation_queued!
    harvest_report.load_queued!
  end

  def prepare_tmp_directory
    FileUtils.mkdir_p(@tmp_directory) unless Dir.exist?(@tmp_directory)
  end

  def move_documents_to_tmp_directory
    Dir.children(@extraction_folder).reject { |f| f.end_with?('tmp') }.each do |folder|
      source = File.join(@extraction_folder, folder)
      dest = File.join(@tmp_directory, folder)

      FileUtils.move(source, dest) if File.exist?(source)
    end
  end

  def create_transformation_jobs
    start_page = @extraction_definition.page
    total_pages = @extraction_job.documents.total_pages

    (start_page..total_pages).each do |page|
      create_transformation_job(page)
      pipeline_job.reload
      break if pipeline_job.cancelled?
    end
  end

  def create_transformation_job(page)
    TransformationWorker.perform_async_with_priority(
      pipeline_job.job_priority,
      harvest_job.id,
      page,
      api_record_id(page)
    )

    harvest_report.increment_transformation_workers_queued!
  end

  def api_record_id(page)
    return nil unless @extraction_definition.enrichment?

    doc = @extraction_job.documents[page]
    return nil unless doc&.file_path

    match = doc.file_path.match(/__(?<record_id>.+)__/)
    match[:record_id] if match
  end

  def folder_number(page = 1)
    (page / Extraction::Documents::DOCUMENTS_PER_FOLDER.to_f).ceil
  end

  def ensure_process_method_implemented
    return if respond_to?(:process_extracted_documents)

    raise NotImplementedError, "#{self.class} must implement `process_extracted_documents`"
  end

  # Abstract methods to be implemented in subclasses
  def process_extracted_documents
    raise NotImplementedError, "#{self.class} must implement `process_extracted_documents`"
  end

  def create_document
    raise NotImplementedError, "#{self.class} must implement `create_document`"
  end
end
