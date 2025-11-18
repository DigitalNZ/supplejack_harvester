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
      perform_initial_extraction
      return if should_stop_early?

      perform_paginated_extraction
    rescue StandardError => e
      handle_extraction_error(e)
    end

    def perform_initial_extraction
      extract(@extraction_definition.requests.first)
    end

    def should_stop_early?
      @extraction_job.is_sample? || set_number_reached? || !@extraction_definition.paginated?
    end

    def perform_paginated_extraction
      throttle
      loop do
        next_page
        extract(@extraction_definition.requests.last)
        throttle
        break if execution_cancelled? || stop_condition_met?
      end
    end

    def handle_extraction_error(_error)
      harvest_definition = @extraction_definition&.harvest_definitions&.first
      source_id = harvest_definition&.source_id
      return unless source_id

      log_stop_condition_hit(stop_condition_type: 'system', stop_condition_name: 'Handle extraction error',
                             stop_condition_content: '')
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
      [set_number_reached?, extraction_failed?, duplicate_document_extracted?, custom_stop_conditions_met?].any?(true)
    end

    def set_number_reached?
      return false if @harvest_job.blank?

      pipeline_job = @harvest_job.pipeline_job
      return false unless pipeline_job.set_number?

      return false unless pipeline_job.pages == @extraction_definition.page

      log_stop_condition_hit(stop_condition_type: 'system', stop_condition_name: 'Set number reached',
                             stop_condition_content: '')
      true
    end

    def extraction_failed?
      document_status = @de.document.status
      return false unless document_status >= 400 || document_status < 200

      log_stop_condition_hit(stop_condition_type: 'system', stop_condition_name: 'Extraction failed',
                             stop_condition_content: '')
      true
    end

    def duplicate_document_extracted?
      previous_doc = previous_document
      return false if previous_doc.nil?

      check_for_duplicate_document(previous_doc)
    end

    def previous_document
      previous_page = @extraction_definition.page - 1
      Extraction::Documents.new(@extraction_job.extraction_folder)[previous_page]
    end

    def check_for_duplicate_document(previous_document)
      return false unless previous_document.body == @de.document.body

      log_stop_condition_hit(stop_condition_type: 'system', stop_condition_name: 'Duplicate document',
                             stop_condition_content: '')
      true
    end

    def custom_stop_conditions_met?
      stop_conditions = @extraction_definition.stop_conditions
      return false if stop_conditions.empty?

      stop_conditions.any? do |condition|
        condition.evaluate(@de.document.body)
        log_stop_condition_hit(stop_condition_type: 'user', stop_condition_name: condition.name,
                               stop_condition_content: condition.content)
      end
    end

    def log_stop_condition_hit(stop_condition_type:, stop_condition_name:, stop_condition_content:)
      JobCompletionServices::ContextBuilder.create_job_completion_or_error({
                                                                             origin: 'Extraction::Execution',
                                                                             definition: @extraction_definition,
                                                                             job: @extraction_job,
                                                                             stop_condition_type:
                                                                               stop_condition_type,
                                                                             stop_condition_name:
                                                                               stop_condition_name,
                                                                             stop_condition_content:
                                                                               stop_condition_content
                                                                           })
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
