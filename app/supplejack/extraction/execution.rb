# frozen_string_literal: true

require 'zlib'
require 'archive/tar/minitar'

module Extraction
  # Performs the work as defined in the document extraction
  class Execution
    def initialize(job, extraction_definition)
      @extraction_job = job
      @extraction_definition = extraction_definition
      @harvest_job = @extraction_job.harvest_job
      @harvest_report = @harvest_job.harvest_report if @harvest_job.present?
    end

    def call
      extract(@extraction_definition.requests.first)
      return if @extraction_job.is_sample? || set_number_reached?
      return unless @extraction_definition.paginated?

      throttle

      loop do
        next_page
        extract(@extraction_definition.requests.last)
        throttle

        break if execution_cancelled? || stop_condition_met?
      end
    end

    private

    def extract(request)
      if @extraction_definition.format == 'ARCHIVE_JSON'
        extract_archive_and_save(request)
      else
        extract_and_save_document(request)
      end
    end

    def next_page
      @extraction_definition.page += 1
    end

    def execution_cancelled?
      @extraction_job.reload.cancelled?
    end

    def stop_condition_met?
      [set_number_reached?, extraction_failed?, duplicate_document_extracted?, custom_stop_conditions_met?].any?(true)
    end

    def set_number_reached?
      return false unless @harvest_job.present? && @harvest_job.pipeline_job.set_number?

      @harvest_job.pipeline_job.pages == @extraction_definition.page
    end

    def extraction_failed?
      @de.document.status >= 400 || @de.document.status < 200
    end

    def duplicate_document_extracted?
      previous_page = @extraction_definition.page - 1
      previous_document = Extraction::Documents.new(@extraction_job.extraction_folder)[previous_page]

      return false if previous_document.nil?

      previous_document.body == @de.document.body
    end

    def custom_stop_conditions_met?
      stop_conditions = @extraction_definition.stop_conditions
      return false if stop_conditions.empty?

      stop_conditions.map { |condition| condition.evaluate(@de.document.body) }.any?(true)
    end

    def throttle
      sleep @extraction_definition.throttle / 1000.0
    end

    def extract_archive_and_save(request)
      extraction_folder = @extraction_job.extraction_folder
      @de = ArchiveExtraction.new(request, extraction_folder, @previous_request)
      @de.download_archive
      @de.save_entries(extraction_folder)
    end

    def extract_and_save_document(request)
      @de = DocumentExtraction.new(request, @extraction_job.extraction_folder, @previous_request)
      @previous_request = @de.extract

      return if duplicate_document_extracted?

      @de.save

      if @harvest_report.present?
        @harvest_report.increment_pages_extracted!
        @harvest_report.update(extraction_updated_time: Time.zone.now)
      end

      enqueue_record_transformation
    end

    def enqueue_record_transformation
      return unless @harvest_job.present? && @de.document.successful?
      return if requires_additional_processing?

      TransformationWorker.perform_async_with_priority(@harvest_job.pipeline_job.job_priority, @harvest_job.id,
                                                       @extraction_definition.page)
      @harvest_report.increment_transformation_workers_queued!
    end

    def requires_additional_processing?
      @extraction_definition.split? || @extraction_definition.extract_text_from_file?
    end
  end
end
