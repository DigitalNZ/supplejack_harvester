# frozen_string_literal: true

module Extraction
  # Helper methods for pre-extraction processing
  # rubocop:disable Metrics/ModuleLength
  module PreExtractionHelpers
    def perform_pre_extraction
      extract(@extraction_definition.requests.first)
      return if @de&.document.blank?

      links = extract_links_from_document(@de.document, 1)
      @extraction_job.update_extracted_links_for_depth(1, links) if @extraction_job.present?

      save_links_as_documents(links)
      update_harvest_report_timestamp
    end

    def perform_extraction_from_pre_extraction
      context = initialize_extraction_context
      max_depth = context[:max_depth]

      (1..max_depth).each do |depth|
        break if should_stop_depth_processing?(context)

        process_depth(context, depth)
        advance_to_next_depth(context) unless depth == max_depth
      end

      finalize_extraction
    end

    def initialize_extraction_context
      pre_extraction_job = ExtractionJob.find(@extraction_job.pre_extraction_job_id)
      documents = pre_extraction_job.documents

      build_context(pre_extraction_job, documents)
    end

    def process_depth(context, depth)
      if depth == context[:max_depth]
        process_final_depth(context)
      else
        process_intermediate_depth(context, depth)
      end
    end

    def process_intermediate_depth(context, depth)
      next_depth = depth + 1
      each_link_document_in_range(context) do |page_number, url|
        document = fetch_document_for_page(page_number, url)
        next unless document&.successful?

        links = extract_links_from_document(document, next_depth)
        next if links.empty?

        save_extracted_links(context, links, next_depth)
        throttle
      end
    end

    def process_final_depth(context)
      each_link_document_in_range(context) do |page_number, url|
        document = fetch_document_for_page(page_number, url)
        next unless document&.successful?

        context[:record_page] += 1
        save_final_content(context)
        throttle
      end
    end

    def each_link_document_in_range(context)
      (context[:start_page]..context[:end_page]).each do |page_number|
        break if execution_cancelled?

        doc = context[:documents][page_number]
        next unless pre_extraction_link_document?(doc)

        url = extract_url_from_pre_extraction_document(doc)
        yield page_number, url if url.present?
      end
    end

    def fetch_document_for_page(page_number, url)
      request = build_request_for_url(url)
      @extraction_definition.page = page_number

      @de = DocumentExtraction.new(request, @extraction_job.extraction_folder, @previous_request)
      @previous_request = @de.extract

      return nil if duplicate_document_extracted?

      @de.document.presence
    end

    def save_extracted_links(context, links, next_depth)
      pre_extraction_job = context[:pre_extraction_job]
      update_extracted_links_tracking(pre_extraction_job, next_depth.to_s, links)
      save_links_to_folder(context, links, pre_extraction_job.extraction_folder)
    end

    def save_final_content(context)
      original_page = @extraction_definition.page
      @extraction_definition.page = context[:record_page]

      @de.save
      update_harvest_report_on_save
      maybe_enqueue_transformation

      @extraction_definition.page = original_page
    end

    def advance_to_next_depth(context)
      context[:start_page] = context[:end_page] + 1
      pre_extraction_folder = context[:pre_extraction_job].extraction_folder
      context[:documents] = Extraction::Documents.new(pre_extraction_folder)
      context[:end_page] = context[:documents].total_pages
    end

    def finalize_extraction
      return unless @harvest_report.present? && @extraction_job.pre_extraction?

      @harvest_report.update(extraction_updated_time: Time.zone.now)
    end

    private

    def build_context(pre_extraction_job, documents)
      total_pages = documents.total_pages
      {
        pre_extraction_job: pre_extraction_job,
        max_depth: @extraction_definition.pre_extraction_depth,
        documents: documents,
        start_page: 1,
        end_page: total_pages,
        cumulative_page: total_pages,
        record_page: 0
      }
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

    def should_stop_depth_processing?(context)
      end_page = context[:end_page]
      context[:start_page] > end_page || end_page.zero?
    end

    def update_extracted_links_tracking(pre_extraction_job, depth_key, links)
      return if pre_extraction_job.blank?

      current_links = pre_extraction_job.extracted_links_by_depth || {}
      depth_links = (current_links[depth_key] || []) + links
      pre_extraction_job.update_extracted_links_for_depth(depth_key.to_i, depth_links.uniq)
    end

    def save_links_to_folder(context, links, extraction_folder)
      links.each do |link_url|
        new_page = context[:cumulative_page] + 1
        context[:cumulative_page] = new_page
        save_link_as_document(link_url, new_page, extraction_folder)
      end
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
