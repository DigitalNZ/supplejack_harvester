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
    rescue StandardError => error
      return unless @extraction_definition&.harvest_definition&.source_id

      harvest_definition = @extraction_definition.harvest_definition
      exception_class = error.class
      exception_message = error.message

      Supplejack::JobCompletionSummaryLogger.log_error(
        extraction_id: harvest_definition.source_id,
        extraction_name: harvest_definition.name,
        message: "Extraction execution error: #{exception_class} - #{exception_message}",
        details: {
          worker_class: self.class.name,
          exception_class: exception_class.name,
          exception_message: exception_message,
          stack_trace: e.backtrace&.first(20),
          extraction_job_id: @extraction_job.id,
          extraction_definition_id: @extraction_definition.id,
          harvest_job_id: @harvest_job&.id,
          harvest_report_id: @harvest_report&.id,
          timestamp: Time.current.iso8601
        }
      )
      rescue StandardError => error
        Rails.logger.error "Failed to log extraction error to JobCompletionSummary: #{error.message}"
      end
      raise
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
      [set_number_reached?, extraction_failed?, duplicate_document_extracted?, custom_stop_conditions_met?].any?
    end

    def set_number_reached?
      return false unless @harvest_job.present? && @harvest_job.pipeline_job.set_number?

      if @harvest_job.pipeline_job.pages == @extraction_definition.page
        log_stop_condition_hit('set_number_reached', 'Set number limit reached',
                               { condition_type: 'set_number_reached' })
        return true
      end

      false
    end

    def extraction_failed?
      if @de.document.status >= 400 || @de.document.status < 200
        log_stop_condition_hit('extraction_failed', "Extraction failed with status #{@de.document.status}",
                               { condition_type: 'extraction_failed' })
        return true
      end

      false
    end

    def duplicate_document_extracted?
      previous_page = @extraction_definition.page - 1
      previous_document = Extraction::Documents.new(@extraction_job.extraction_folder)[previous_page]

      return false if previous_document.nil?

      if previous_document.body == @de.document.body
        log_stop_condition_hit('duplicate_document', 'Duplicate document detected',
                               { condition_type: 'duplicate_document' })
        return true
      end

      false
    end

    def custom_stop_conditions_met?
      stop_conditions = @extraction_definition.stop_conditions
      return false if stop_conditions.empty?

      stop_conditions.any? { |condition| condition.evaluate(@de.document.body, self) }
    end

    def log_stop_condition_hit(name, content, additional_details = {})
      Supplejack::JobCompletionSummaryLogger.log_stop_condition_hit(
        extraction_definition: @extraction_definition,
        stop_condition_name: name,
        stop_condition_content: content,
        extraction_job: @extraction_job,
        harvest_job: @harvest_job,
        document: @de&.document,
        additional_details: additional_details
      )
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
