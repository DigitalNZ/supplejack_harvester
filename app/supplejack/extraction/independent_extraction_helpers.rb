# frozen_string_literal: true

module Extraction
  # Helper methods for independent-extraction processing
  module IndependentExtractionHelpers
    def perform_independent_extraction
      extract(@extraction_definition.requests.first)
      return if @de&.document.blank?

      links = extract_links_from_document(@de.document)

      save_links_as_documents(links)
      update_harvest_report_timestamp
    end

    def perform_extraction_from_independent_extraction
      independent_extraction_job = ExtractionJob.find(@extraction_job.independent_extraction_job_id)
      documents = independent_extraction_job.documents

      if @extraction_job.independent_extraction?
        # Independent-extraction step: extract links from each fetched page
        perform_link_extraction_from_documents(documents)
      else
        # Pipeline step: save content from each fetched page for transformation
        perform_content_extraction_from_documents(documents)
      end
    end

    private

    def perform_link_extraction_from_documents(documents)
      all_extracted_links = collect_links_from_documents(documents)
      save_links_as_documents(all_extracted_links)
      update_harvest_report_timestamp
    end

    def collect_links_from_documents(documents)
      [].tap do |links|
        (1..documents.total_pages).each do |page_number|
          break if execution_cancelled?

          extracted = extract_links_from_page(documents[page_number])
          links.concat(extracted) if extracted
        end
      end
    end

    def extract_links_from_page(doc)
      return nil unless independent_extraction_link_document?(doc)

      url = extract_url_from_independent_extraction_document(doc)
      return nil if url.blank?

      document = fetch_document_for_page(url)
      return nil unless document&.successful?

      throttle
      extract_links_from_document(document)
    end

    def perform_content_extraction_from_documents(documents)
      record_page = 0

      (1..documents.total_pages).each do |page_number|
        break if execution_cancelled?

        record_page = process_content_page(documents[page_number], record_page)
      end
    end

    def process_content_page(doc, record_page)
      return record_page unless should_process_document?(doc)

      record_page += 1
      @extraction_definition.page = record_page
      @de.save

      update_harvest_report_on_extract
      enqueue_record_transformation
      throttle
      record_page
    end

    def should_process_document?(doc)
      return false unless independent_extraction_link_document?(doc)

      url = extract_url_from_independent_extraction_document(doc)
      return false if url.blank?

      document = fetch_document_for_page(url)
      document&.successful?
    end

    def fetch_document_for_page(url)
      request = build_request_for_url(url)

      @de = DocumentExtraction.new(request, @extraction_job.extraction_folder, @previous_request)
      @previous_request = @de.extract

      return nil if duplicate_document_extracted?

      @de.document.presence
    end

    def update_harvest_report_on_extract
      return if @harvest_report.blank?

      @harvest_report.increment_pages_extracted!
      @harvest_report.update(extraction_updated_time: Time.zone.now)
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
  end
end

