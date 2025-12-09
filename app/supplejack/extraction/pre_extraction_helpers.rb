# frozen_string_literal: true

module Extraction
  # Helper methods for pre-extraction processing
  # :reek:FeatureEnvy - These methods intentionally work with context hash and external objects
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

        is_final_depth = depth == max_depth
        if is_final_depth
          process_final_depth(context)
        else
          process_intermediate_depth(context, depth)
        end

        advance_to_next_depth(context) unless is_final_depth
      end

      finalize_extraction
    end

    # Sets up all the tracking state for pre-extraction processing
    def initialize_extraction_context
      pre_extraction_job = ExtractionJob.find(@extraction_job.pre_extraction_job_id)
      documents = pre_extraction_job.documents
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

    # Intermediate depths: fetch pages, extract links, save as new link documents
    def process_intermediate_depth(context, depth)
      each_link_document_in_range(context) do |page_number, url|
        document = fetch_document_for_page(page_number, url)
        next unless document&.successful?

        next_depth = depth + 1
        links = extract_links_from_document(document, next_depth)
        next if links.empty?

        Rails.logger.info "Depth #{depth} (INTERMEDIATE): Extracted #{links.count} links from #{url}"

        save_extracted_links(context, links, next_depth)
        throttle
      end
    end

    # Final depth: fetch actual content and save to main job folder
    def process_final_depth(context)
      each_link_document_in_range(context) do |page_number, url|
        document = fetch_document_for_page(page_number, url)
        next unless document&.successful?

        context[:record_page] += 1
        save_final_content(context)
        throttle
      end
    end

    # Iterates over link documents in the current page range
    def each_link_document_in_range(context)
      (context[:start_page]..context[:end_page]).each do |page_number|
        break if execution_cancelled?

        doc = context[:documents][page_number]
        next unless is_pre_extraction_link_document?(doc)

        url = extract_url_from_pre_extraction_document(doc)
        next if url.blank?

        yield page_number, url
      end
    end

    # Fetches and extracts a document from the given URL
    def fetch_document_for_page(page_number, url)
      request = build_request_for_url(url)
      @extraction_definition.page = page_number

      @de = DocumentExtraction.new(request, @extraction_job.extraction_folder, @previous_request)
      @previous_request = @de.extract

      return nil if duplicate_document_extracted?

      document = @de.document
      return nil if document.blank?

      document
    end

    # Saves extracted links to the pre-extraction folder
    def save_extracted_links(context, links, next_depth)
      pre_extraction_job = context[:pre_extraction_job]
      depth_key = next_depth.to_s

      update_extracted_links_tracking(pre_extraction_job, depth_key, links)
      save_links_to_folder(context, links, pre_extraction_job.extraction_folder)
    end

    # Saves final content to the main extraction job folder
    def save_final_content(context)
      original_page = @extraction_definition.page
      @extraction_definition.page = context[:record_page]

      @de.save

      if @harvest_report.present?
        @harvest_report.increment_pages_extracted!
        @harvest_report.update(extraction_updated_time: Time.zone.now)
      end

      document = @de&.document
      if !@extraction_job.pre_extraction? && document.present? && document.successful?
        enqueue_record_transformation
      end

      @extraction_definition.page = original_page
    end

    # Moves to the next depth level by updating page ranges
    # :reek:UtilityFunction - Intentionally stateless helper for context hash manipulation
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

    def save_links_as_documents(links)
      links.each_with_index do |link_url, index|
        page_number = index + 1
        save_link_as_document(link_url, page_number)
        @harvest_report.increment_pages_extracted! if @harvest_report.present?
      end
    end

    def update_harvest_report_timestamp
      return if @harvest_report.blank?

      @harvest_report.update(extraction_updated_time: Time.zone.now)
    end

    # :reek:UtilityFunction - Intentionally checks context hash state
    def should_stop_depth_processing?(context)
      end_page = context[:end_page]
      context[:start_page] > end_page || end_page.zero?
    end

    # :reek:UtilityFunction - Intentionally stateless helper for updating external object
    def update_extracted_links_tracking(pre_extraction_job, depth_key, links)
      return unless pre_extraction_job.present?

      current_links = pre_extraction_job.extracted_links_by_depth || {}
      depth_links = current_links[depth_key] || []
      depth_links += links
      pre_extraction_job.update_extracted_links_for_depth(depth_key.to_i, depth_links.uniq)
    end

    def save_links_to_folder(context, links, extraction_folder)
      links.each do |link_url|
        context[:cumulative_page] += 1
        current_page = context[:cumulative_page]
        save_link_as_document_to_folder(link_url, current_page, extraction_folder)
      end
    end
  end
end
