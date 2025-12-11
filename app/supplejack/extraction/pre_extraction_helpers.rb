# frozen_string_literal: true

module Extraction
  # Helper methods for pre-extraction processing
  module PreExtractionHelpers
    def perform_pre_extraction
      extract(@extraction_definition.requests.first)
      return if @de&.document.blank?

      links = extract_links_from_document(@de.document)

      save_links_as_documents(links)
      update_harvest_report_timestamp
    end

    def perform_extraction_from_pre_extraction
      pre_extraction_job = ExtractionJob.find(@extraction_job.pre_extraction_job_id)
      documents = pre_extraction_job.documents
      record_page = 0

      (1..documents.total_pages).each do |page_number|
        break if execution_cancelled?

        doc = documents[page_number]
        next unless pre_extraction_link_document?(doc)

        url = extract_url_from_pre_extraction_document(doc)
        next if url.blank?

        document = fetch_document_for_page(page_number, url)
        next unless document&.successful?

        record_page += 1
        save_final_content(record_page)
        throttle
      end

      finalize_extraction
    end

    private

    def fetch_document_for_page(page_number, url)
      request = build_request_for_url(url)
      @extraction_definition.page = page_number

      @de = DocumentExtraction.new(request, @extraction_job.extraction_folder, @previous_request)
      @previous_request = @de.extract

      return nil if duplicate_document_extracted?

      @de.document.presence
    end

    def save_final_content(page_number)
      original_page = @extraction_definition.page
      @extraction_definition.page = page_number

      @de.save
      update_harvest_report_on_save
      maybe_enqueue_transformation

      @extraction_definition.page = original_page
    end

    def update_harvest_report_on_save
      return if @harvest_report.blank?

      @harvest_report.increment_pages_extracted!
      @harvest_report.update(extraction_updated_time: Time.zone.now)
    end

    def maybe_enqueue_transformation
      document = @de&.document
      return unless !@extraction_job.pre_extraction? && document.present? && document.successful?

      enqueue_record_transformation
    end

    def save_links_as_documents(links)
      links.each_with_index do |link_url, index|
        save_link_as_document(link_url, index + 1)
        @harvest_report.increment_pages_extracted! if @harvest_report.present?
      end
    end

    def update_harvest_report_timestamp
      @harvest_report&.update(extraction_updated_time: Time.zone.now)
    end

    def finalize_extraction
      return unless @harvest_report.present? && @extraction_job.pre_extraction?

      @harvest_report.update(extraction_updated_time: Time.zone.now)
    end
  end
end
