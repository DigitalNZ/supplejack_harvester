# frozen_string_literal: true

require 'zlib'
require 'archive/tar/minitar'
require 'jsonpath'
require 'nokogiri'
require 'uri'
require 'json'

module Extraction
  # Simple wrapper for Request that uses a specific URL from pre-extraction
  class PreExtractionRequest
    def initialize(base_request, url)
      @base_request = base_request
      @url = url
    end

    def url(_response = nil)
      @url
    end

    def query_parameters(response = nil)
      @base_request.query_parameters(response)
    end

    def headers(response = nil)
      @base_request.headers(response)
    end

    def extraction_definition
      @base_request.extraction_definition
    end

    def http_method
      @base_request.http_method
    end
  end

  # Performs the work as defined in the document extraction
  class Execution
    def initialize(job, extraction_definition)
      @extraction_job = job
      @extraction_definition = extraction_definition
      @harvest_job = @extraction_job.harvest_job
      @harvest_report = @harvest_job.harvest_report if @harvest_job.present?
    end

    def call
      # Check for pre_extraction_job_id FIRST - if we have one, we're extracting from pre-extraction
      if @extraction_job.pre_extraction_job_id.present?
        perform_extraction_from_pre_extraction
        return
      end

      # Then check if this extraction job is for pre-extraction (based on step type, not definition)
      if @extraction_job.pre_extraction?
        perform_pre_extraction
        return
      end

      perform_initial_extraction
      return if should_stop_early? || custom_stop_conditions_met?

      perform_paginated_extraction
    rescue StandardError => e
      Rails.logger.error "Error in Extraction::Execution#call: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
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

    def perform_pre_extraction
      extract(@extraction_definition.requests.first)

      # Add guard clause
      return unless @de&.document&.present?

      links = extract_links_from_document(@de.document, 1)

      # Add check for empty links - but log why
      if links.empty?
        selector = @extraction_definition.link_selector_for_depth(1)
        if selector.blank?
          Rails.logger.warn "[PRE-EXTRACTION] No selector set for depth 1 and no links extracted. Please configure a link selector for level 1."
        else
          Rails.logger.warn "[PRE-EXTRACTION] Selector configured but no links found. Selector: #{selector}"
        end
        return
      end

      # Store extracted links for depth 1
      if @extraction_job.present?
        @extraction_job.update_extracted_links_for_depth(1, links)
      end

      links.each_with_index do |link_url, index|
        page_number = index + 1
        save_link_as_document(link_url, page_number)

        if @harvest_report.present?
          @harvest_report.increment_pages_extracted!
        end
      end

      if @harvest_report.present?
        @harvest_report.update(extraction_updated_time: Time.zone.now)
      end
    end

    def perform_extraction_from_pre_extraction
      pre_extraction_job = ExtractionJob.find(@extraction_job.pre_extraction_job_id)
      max_depth = @extraction_definition.pre_extraction_depth

      Rails.logger.info "Pre-extraction depth: #{max_depth} (extraction_definition_id: #{@extraction_definition.id})"

      # Load initial documents from pre-extraction job
      current_documents = pre_extraction_job.documents
      
      # Track the page range for each depth
      # Depth 1 processes pages 1 to initial_count (saved by perform_pre_extraction)
      current_start_page = 1
      current_end_page = current_documents.total_pages
      
      # Start numbering NEW pages AFTER existing ones (to avoid overwriting)
      cumulative_page_counter = current_end_page
      
      # Separate counter for final content saved to main extraction job
      main_job_page_counter = 0

      Rails.logger.info "Initial state: pages 1 to #{current_end_page} available"

      (1..max_depth).each do |depth|
        Rails.logger.info "Processing depth #{depth} of #{max_depth} - pages #{current_start_page} to #{current_end_page}"

        # No pages to process for this depth
        if current_start_page > current_end_page || current_end_page == 0
          Rails.logger.warn "No pages to process at depth #{depth}, stopping extraction"
          break
        end

        link_counter = 0
        saved_links = []
        saved_content_count = 0

        # Process ONLY pages in the current depth's range
        (current_start_page..current_end_page).each do |page_number|
          break if execution_cancelled?

          doc = current_documents[page_number]

          # Skip documents that aren't pre-extraction link documents
          next unless is_pre_extraction_link_document?(doc)

          url = extract_url_from_pre_extraction_document(doc)
          next if url.blank?

          request = build_request_for_url(url)
          @extraction_definition.page = page_number

          Rails.logger.info "[EXTRACTION] Fetching URL: #{url}, depth: #{depth}, max_depth: #{max_depth}"

          @de = DocumentExtraction.new(request, @extraction_job.extraction_folder, @previous_request)
          @previous_request = @de.extract

          if @de.document.present?
            Rails.logger.info "[EXTRACTION] Document extracted - Status: #{@de.document.status}, URL: #{@de.document.url}"
          else
            Rails.logger.warn "[EXTRACTION] Document extraction returned nil for URL: #{url}"
          end

          next if duplicate_document_extracted?
          next unless @de.document.present? && @de.document.successful?

          if depth == max_depth
            # Final depth: save the document content to MAIN extraction job folder
            main_job_page_counter += 1  # Changed from cumulative_page_counter

            original_page = @extraction_definition.page
            @extraction_definition.page = main_job_page_counter  # Changed

            Rails.logger.info "[EXTRACTION] Saving final content - URL: #{url}, Page: #{main_job_page_counter}"

            @de.save
            saved_content_count += 1

            if @harvest_report.present?
              @harvest_report.increment_pages_extracted!
              @harvest_report.update(extraction_updated_time: Time.zone.now)
            end

            unless @extraction_job.pre_extraction?
              if @de.present? && @de.document.present? && @de.document.successful?
                enqueue_record_transformation
              end
            end

            @extraction_definition.page = original_page
          else
            # Intermediate depth: extract links using NEXT depth's selector
            next_depth = depth + 1
            links = extract_links_from_document(@de.document, next_depth)

            next if links.empty?

            Rails.logger.info "Depth #{depth} (INTERMEDIATE): Extracted #{links.count} links from #{url}"

            # Store extracted links for UI display
            if pre_extraction_job.present?
              current_links = pre_extraction_job.extracted_links_by_depth || {}
              current_links[next_depth.to_s] ||= []
              current_links[next_depth.to_s] += links
              pre_extraction_job.update_extracted_links_for_depth(next_depth, current_links[next_depth.to_s].uniq)
            end

            # Save links with page numbers AFTER current pages (no overwriting!)
            links.each do |link_url|
              link_counter += 1
              cumulative_page_counter += 1
              save_link_as_document_to_folder(link_url, cumulative_page_counter, pre_extraction_job.extraction_folder)
              saved_links << link_url
            end
          end

          throttle
        end

        Rails.logger.info "Depth #{depth} complete. Saved #{depth == max_depth ? saved_content_count : link_counter} items"

        # Prepare for next depth (if not at final depth)
        if depth < max_depth
          # Next depth starts where we left off (after the pages we just processed)
          # and goes to the new total (including pages we just saved)
          current_start_page = current_end_page + 1

          # Reload documents to see newly saved links
          current_documents = Extraction::Documents.new(pre_extraction_job.extraction_folder)

          current_end_page = current_documents.total_pages

          Rails.logger.info "Depth #{depth} complete. Next depth will process pages #{current_start_page} to #{current_end_page}"

          if current_start_page > current_end_page
            Rails.logger.warn "No new documents found after depth #{depth}, stopping extraction"
            break
          end
        else
          Rails.logger.info "Final depth #{depth} complete."
        end
      end

      Rails.logger.info "Pre-extraction complete. Final document count: #{@extraction_job.documents.total_pages}"

      if @harvest_report.present? && @extraction_job.pre_extraction?
        @harvest_report.update(extraction_updated_time: Time.zone.now)
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
      return false if @de.document.nil?
      
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
      return false if @de.document.nil? || previous_document.nil?
      return false unless previous_document.body == @de.document.body

      log_stop_condition_hit(stop_condition_type: 'system', stop_condition_name: 'Duplicate document',
                             stop_condition_content: '')
      true
    end

    def custom_stop_conditions_met?
      stop_conditions = @extraction_definition.stop_conditions
      return false if stop_conditions.empty?
      return false if @de.document.nil?

      stop_conditions.any? do |condition|
        condition.evaluate(@de.document.body).tap do |met|
          if met
            log_stop_condition_hit(
              stop_condition_type: 'user',
              stop_condition_name: condition.name,
              stop_condition_content: condition.content
            )
          end
        end
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

      # Log document details before saving
      document_body_preview = @de.document.body.to_s[0..200] rescue "Unable to preview body"
      is_link_document = is_link_document_body?(@de.document.body)
      
      Rails.logger.info "[EXTRACTION] Saving document - Page: #{@extraction_definition.page}, URL: #{@de.document.url}, " \
                        "Is link document: #{is_link_document}, Body preview: #{document_body_preview}..."
      
      @de.save

      if @harvest_report.present?
        @harvest_report.increment_pages_extracted!
        @harvest_report.update(extraction_updated_time: Time.zone.now)
      end

      Rails.logger.info "[EXTRACTION] About to enqueue transformation for page #{@extraction_definition.page}"
      enqueue_record_transformation
    end

    def enqueue_record_transformation

      unless @harvest_job.present?
        Rails.logger.warn "[TRANSFORMATION] Cannot enqueue transformation: harvest_job is nil"
        return
      end
      
      unless @de.document.successful?
        Rails.logger.warn "[TRANSFORMATION] Cannot enqueue transformation: document not successful (status: #{@de.document.status})"
        return
      end
      
      # Check if this is a link document
      is_link_doc = is_link_document_body?(@de.document.body)
      if is_link_doc
        Rails.logger.warn "[TRANSFORMATION] SKIPPING transformation for page #{@extraction_definition.page} - " \
                          "This is a link document (pre_extraction_link: true). Body preview: #{@de.document.body.to_s[0..200]}"
        return
      end
      
      if requires_additional_processing?
        Rails.logger.info "[TRANSFORMATION] Skipping immediate transformation - requires additional processing (split: #{@extraction_definition.split?}, extract_text: #{@extraction_definition.extract_text_from_file?})"
        return
      end

      Rails.logger.info "[TRANSFORMATION] Enqueueing transformation for page #{@extraction_definition.page}, " \
                        "harvest_job_id: #{@harvest_job.id}, priority: #{@harvest_job.pipeline_job.job_priority}"
      
      TransformationWorker.perform_async_with_priority(@harvest_job.pipeline_job.job_priority, @harvest_job.id,
                                                       @extraction_definition.page)
      @harvest_report.increment_transformation_workers_queued!
      
      Rails.logger.info "[TRANSFORMATION] Successfully enqueued transformation for page #{@extraction_definition.page}"
    end

    def requires_additional_processing?
      @extraction_definition.split? || @extraction_definition.extract_text_from_file?
    end

    def extract_links_from_document(document, depth = 1)
      body = document.body
      format = @extraction_definition.format
      
      # Auto-detect format if it doesn't match the content
      # For HTML format, also check if it's actually XML (sitemap)
      if format == 'JSON' && !(body.strip.start_with?('{') || body.strip.start_with?('['))
        format = detect_format_from_content(body)
      elsif format == 'XML' && !body.strip.start_with?('<?xml') && !body.strip.start_with?('<')
        format = detect_format_from_content(body)
      elsif format == 'HTML'
        # Check if it's actually XML (sitemap) - XML sitemaps start with <?xml or <urlset
        if body.strip.start_with?('<?xml') || (body.strip.start_with?('<') && (body.include?('<urlset') || body.include?('<sitemap')))
          format = 'XML'
        elsif !body.include?('<html') && !body.include?('<!DOCTYPE') && !body.include?('<')
          format = detect_format_from_content(body)
        end
      end
      
      Rails.logger.info "[EXTRACTION] extract_links_from_document - original format: #{@extraction_definition.format}, detected format: #{format}, depth: #{depth}"
      
      case format
      when 'JSON'
        extract_json_links(body, depth)
      when 'XML'
        extract_xml_links(body, depth)
      when 'HTML'
        extract_html_links(body, depth)
      else
        []
      end
    end

    def detect_format_from_content(body)
      return 'XML' if body.strip.start_with?('<?xml') || (body.strip.start_with?('<') && body.include?('<?xml'))
      return 'JSON' if body.strip.start_with?('{') || body.strip.start_with?('[')
      return 'HTML' if body.include?('<html') || body.include?('<!DOCTYPE') || body.include?('<')
      'HTML' # Default
    end

    def extract_json_links(body, depth = 1)
      parsed = JSON.parse(body)

      # Get depth-specific selector
      selector = @extraction_definition.link_selector_for_depth(depth)

      if selector.present?
        JsonPath.new(selector).on(parsed)
      else
        # Return empty array if no selector - don't use default behavior
        Rails.logger.info "[EXTRACTION] No selector for depth #{depth}, returning empty array"
        []
      end
    rescue JSON::ParserError
      []
    end

    def extract_xml_links(body, depth = 1)
      doc = Nokogiri::XML.parse(body)
      
      # Get depth-specific selector
      selector = @extraction_definition.link_selector_for_depth(depth)
      
      Rails.logger.info "[EXTRACTION] extract_xml_links - depth: #{depth}, selector: #{selector.inspect}, format: #{@extraction_definition.format}"
      
      if selector.present?
        # Check if it's XPath (starts with / or //)
        if selector.start_with?('/')
          links = doc.xpath(selector).map do |node|
            # Extract href attribute or text content
            node['href'] || node['url'] || node.text
          end.compact
          Rails.logger.info "[EXTRACTION] XPath selector returned #{links.count} links"
          links
        else
          # Fallback to CSS selector
          links = doc.css(selector).map { |node| node['href'] || node['url'] || node.text }.compact
          Rails.logger.info "[EXTRACTION] CSS selector returned #{links.count} links"
          links
        end
      else
        # Return empty array if no selector - don't use default behavior
        Rails.logger.info "[EXTRACTION] No selector for depth #{depth}, returning empty array"
        []
      end
    rescue Nokogiri::XML::SyntaxError => e
      Rails.logger.error "[EXTRACTION] XML parsing error: #{e.message}"
      []
    end

    def extract_html_links(body, depth = 1)
      doc = Nokogiri::HTML.parse(body)
      
      # Get depth-specific selector
      selector = @extraction_definition.link_selector_for_depth(depth)
      
      Rails.logger.info "[EXTRACTION] extract_html_links - depth: #{depth}, selector: #{selector.inspect}"
      
      if selector.present?
        # Check if it's XPath (starts with / or //)
        if selector.start_with?('/')
          # Use XPath
          matched_nodes = doc.xpath(selector)
          Rails.logger.info "[EXTRACTION] XPath matched #{matched_nodes.count} nodes"
          
          # Debug: Log sample of all links in the document if no matches found
          if matched_nodes.count == 0
            all_links = doc.xpath('//body//a[@href]')
            Rails.logger.info "[EXTRACTION] Debug: Found #{all_links.count} total <a> tags with href in document"
            if all_links.count > 0
              sample_texts = all_links.first(10).map { |a| a.text.strip }.reject(&:blank?)
              Rails.logger.info "[EXTRACTION] Debug: Sample link texts (first 10): #{sample_texts.inspect}"
              sample_hrefs = all_links.first(5).map { |a| a['href'] }.compact
              Rails.logger.info "[EXTRACTION] Debug: Sample hrefs (first 5): #{sample_hrefs.inspect}"
            end
          end
          
          links = matched_nodes.map do |node|
            # Handle different node types
            case node
            when Nokogiri::XML::Attr
              # If XPath returns an attribute (e.g., //a/@href), return its value
              node.value
            when Nokogiri::XML::Element
              # If it's an element, get href attribute
              href = node['href'] || node['url']
              if href.present?
                href
              elsif node.text.present?
                # If no href, use text content (might be a URL)
                node.text.strip
              else
                nil
              end
            when Nokogiri::XML::Text
              # If it's a text node, try to get parent's href
              if node.parent && node.parent.name == 'a'
                node.parent['href'] || node.text.strip
              else
                node.text.strip
              end
            else
              # Fallback: try to get href or text
              node.respond_to?(:[]) ? (node['href'] || node['url'] || node.text) : node.to_s
            end
          end.compact.reject(&:blank?)
          
          Rails.logger.info "[EXTRACTION] XPath selector returned #{links.count} links: #{links.first(5).inspect}"
          links
        else
          # Use CSS selector
          links = doc.css(selector).map { |node| node['href'] || node['url'] || node.text }.compact.reject(&:blank?)
          Rails.logger.info "[EXTRACTION] CSS selector returned #{links.count} links"
          links
        end
      else
        # Return empty array if no selector - don't use default behavior
        Rails.logger.info "[EXTRACTION] No selector for depth #{depth}, returning empty array"
        []
      end
    rescue Nokogiri::SyntaxError => e
      Rails.logger.error "[EXTRACTION] HTML parsing error: #{e.message}"
      []
    rescue StandardError => e
      Rails.logger.error "[EXTRACTION] Unexpected error in extract_html_links: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      []
    end

    def normalize_url(url)
      return url if url.start_with?('http://', 'https://')

      base_uri = URI.parse(@extraction_definition.base_url)
      URI.join(base_uri, url).to_s
    rescue URI::InvalidURIError
      url
    end

    def extract_url_from_pre_extraction_document(document)
      body = JSON.parse(document.body)
      body['url'] || body['href'] || body['link']
    rescue JSON::ParserError
      # If it's not JSON, it's not a pre-extraction link document
      nil
    end

    def is_pre_extraction_link_document?(document)
      return false if document.nil?
      
      begin
        body = JSON.parse(document.body)
        body['pre_extraction_link'] == true
      rescue JSON::ParserError
        false
      end
    end

    def is_link_document_body?(body)
      return false if body.nil?
      
      # If it's already a hash/object, check directly
      if body.is_a?(Hash)
        return body['pre_extraction_link'] == true || body[:pre_extraction_link] == true
      end
      
      # Convert to string for pattern matching
      body_str = body.to_s
      
      # Check if it contains the link blob pattern (works for any format)
      return true if body_str.include?('"pre_extraction_link":true') || body_str.include?("'pre_extraction_link':true")
      
      # Try to parse as JSON
      begin
        parsed = JSON.parse(body_str)
        return parsed['pre_extraction_link'] == true if parsed.is_a?(Hash)
      rescue JSON::ParserError
        # Not valid JSON, continue to HTML/XML check
      end
      
      # Try to extract JSON from HTML/XML
      begin
        # Check if it's HTML/XML that might contain JSON
        if body_str.strip.start_with?('<')
          # Try to find JSON within HTML/XML tags
          if body_str.match(/\{"url":.*"pre_extraction_link":\s*true\}/)
            return true
          end
          
          # Try parsing as HTML/XML and extracting text
          doc = Nokogiri::HTML.parse(body_str) rescue Nokogiri::XML.parse(body_str)
          text_content = doc.text.strip
          
          # Try parsing the extracted text as JSON
          if text_content.start_with?('{')
            parsed = JSON.parse(text_content)
            return parsed['pre_extraction_link'] == true if parsed.is_a?(Hash)
          end
        end
      rescue Nokogiri::SyntaxError, JSON::ParserError
        # Not HTML/XML or JSON extraction failed
      end
      
      false
    end

    def build_request_for_url(url)
      base_request = @extraction_definition.requests.first

      # Create a simple wrapper object that mimics Request interface
      # but returns the specific URL from pre-extraction
      PreExtractionRequest.new(base_request, url)
    end

    def save_link_as_document(link_url, page_number)
      full_url = normalize_url(link_url)
    
      link_document = Extraction::Document.new(
        url: full_url,
        method: 'GET',
        params: {},
        request_headers: {},
        status: 200,
        response_headers: {},
        body: { url: full_url, pre_extraction_link: true }.to_json
      )
    
      link_document.save(file_path_for_page(page_number))
    end

    def save_link_as_document_to_folder(link_url, page_number, folder)
      full_url = normalize_url(link_url)
    
      link_document = Extraction::Document.new(
        url: full_url,
        method: 'GET',
        params: {},
        request_headers: {},
        status: 200,
        response_headers: {},
        body: { url: full_url, pre_extraction_link: true }.to_json
      )
    
      link_document.save(file_path_for_page(page_number, folder))
    end

    def file_path_for_page(page_number, folder = nil)
      page_str = format('%09d', page_number)[-9..]
      name_str = @extraction_definition.name.parameterize(separator: '_')
      target_folder = folder || @extraction_job.extraction_folder
      "#{target_folder}/#{folder_number(page_number)}/#{name_str}__-__#{page_str}.json"
    end
    
    def folder_number(page = 1)
      (page / Extraction::Documents::DOCUMENTS_PER_FOLDER.to_f).ceil
    end
  end
end
