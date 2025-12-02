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

      links = extract_links_from_document(@de.document)

      # Add check for empty links
      if links.empty?
        return
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
      
      # Reload extraction definition to ensure we have the latest pre_extraction_depth value
      @extraction_definition.reload
      max_depth = @extraction_definition.pre_extraction_depth || 1
      
      Rails.logger.info "Pre-extraction depth: #{max_depth} (extraction_definition_id: #{@extraction_definition.id}, pre_extraction_depth: #{@extraction_definition.pre_extraction_depth.inspect})"
      
      # TEMPORARY: Limit to 10 pages for testing - REMOVE AFTER TESTING
      max_pages_for_testing = 10
      
      current_documents = pre_extraction_job.documents
      cumulative_page_counter = 0  # Track total pages across all depths
      
      (1..max_depth).each do |depth|
        Rails.logger.info "Processing depth #{depth} of #{max_depth} - current_documents.total_pages: #{current_documents.total_pages}"
        
        total_pages = current_documents.total_pages || 0
        # TEMPORARY: Cap pages for testing - REMOVE AFTER TESTING
        pages_to_process = [total_pages, max_pages_for_testing].min

        link_counter = 0
        saved_links = []
        saved_content_count = 0
        
        (1..pages_to_process).each do |page_number|
          break if execution_cancelled?
          
          doc = current_documents[page_number]
          
          # Skip documents that aren't pre-extraction link documents
          next unless is_pre_extraction_link_document?(doc)
          
          url = extract_url_from_pre_extraction_document(doc)
          next if url.blank?
          
          request = build_request_for_url(url)
          @extraction_definition.page = page_number
          
          @de = DocumentExtraction.new(request, @extraction_job.extraction_folder, @previous_request)
          @previous_request = @de.extract
          
          next if duplicate_document_extracted?
          next unless @de.document.present? && @de.document.successful?
          
          if depth == max_depth
            # Final depth: save the document content
            cumulative_page_counter += 1
            @de.save
            saved_content_count += 1
            
            Rails.logger.info "Depth #{depth} (FINAL): Saved content document #{saved_content_count} for URL: #{url}"
            
            if @harvest_report.present?
              @harvest_report.increment_pages_extracted!
              @harvest_report.update(extraction_updated_time: Time.zone.now)
            end
            
            enqueue_record_transformation unless @extraction_job.pre_extraction?
          else
            # Intermediate depth: extract links
            links = extract_links_from_document(@de.document)
            
            next if links.empty?
            
            Rails.logger.info "Depth #{depth} (INTERMEDIATE): Extracted #{links.count} links from URL: #{url}"
            
            links.each do |link_url|
              link_counter += 1
              cumulative_page_counter += 1
              save_link_as_document(link_url, cumulative_page_counter)  # Use cumulative counter
              saved_links << link_url
            end
          end
          
          throttle
        end
        
        Rails.logger.info "Depth #{depth} complete. Saved #{depth == max_depth ? saved_content_count : link_counter} items (#{depth == max_depth ? 'content' : 'links'})"
        
        # Only reload documents if we're not at the final depth
        if depth < max_depth
          # Reload documents to get the newly saved links
          current_documents = @extraction_job.documents
          
          Rails.logger.info "Depth #{depth} complete. Found #{current_documents.total_pages} documents for next depth"
          
          if current_documents.total_pages == 0
            Rails.logger.warn "No documents found after depth #{depth}, stopping extraction"
            break
          end
        else
          Rails.logger.info "Final depth #{depth} complete. No more depths to process."
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

      @de.save

      if @harvest_report.present?
        @harvest_report.increment_pages_extracted!
        @harvest_report.update(extraction_updated_time: Time.zone.now)
      end

      enqueue_record_transformation
    end

    def enqueue_record_transformation

      unless @harvest_job.present?
        Rails.logger.warn "Cannot enqueue transformation: harvest_job is nil"
        return
      end
      
      unless @de.document.successful?
        Rails.logger.warn "Cannot enqueue transformation: document not successful (status: #{@de.document.status})"
        return
      end
      
      if requires_additional_processing?
        return
      end

      TransformationWorker.perform_async_with_priority(@harvest_job.pipeline_job.job_priority, @harvest_job.id,
                                                       @extraction_definition.page)
      @harvest_report.increment_transformation_workers_queued!
    end

    def requires_additional_processing?
      @extraction_definition.split? || @extraction_definition.extract_text_from_file?
    end

    def extract_links_from_document(document)
      body = document.body
      format = @extraction_definition.format
      
      # Auto-detect format if it doesn't match the content
      if format == 'JSON' && !(body.strip.start_with?('{') || body.strip.start_with?('['))
        format = detect_format_from_content(body)
      elsif format == 'XML' && !body.strip.start_with?('<?xml') && !body.strip.start_with?('<')
        format = detect_format_from_content(body)
      elsif format == 'HTML' && !body.include?('<html') && !body.include?('<!DOCTYPE') && !body.include?('<')
        format = detect_format_from_content(body)
      end
      
      case format
      when 'JSON'
        extract_json_links(body)
      when 'XML'
        extract_xml_links(body)
      when 'HTML'
        extract_html_links(body)
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

    def extract_json_links(body)
      parsed = JSON.parse(body)

      if @extraction_definition.link_selector.present?
        JsonPath.new(@extraction_definition.link_selector).on(parsed)
      else
        parsed['urls'] || parsed['links'] || []
      end
    rescue JSON::ParserError
      []
    end

    def extract_xml_links(body)
      doc = Nokogiri::XML.parse(body)
      doc.css('loc').map(&:text)
    rescue Nokogiri::XML::SyntaxError
      []
    end

    def extract_html_links(body)
      doc = Nokogiri::HTML.parse(body)
      
      # Extract all links, but exclude those inside <nav> elements
      all_links = doc.css('a[href]').reject do |a|
        # Check if this link is inside a <nav> element (any ancestor)
        a.ancestors.any? { |ancestor| ancestor.name == 'nav' }
      end.map { |a| a['href'] }.compact
      
      all_links
    rescue Nokogiri::HTML::SyntaxError
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

    def file_path_for_page(page_number)
      page_str = format('%09d', page_number)[-9..]
      name_str = @extraction_definition.name.parameterize(separator: '_')
      "#{@extraction_job.extraction_folder}/#{folder_number(page_number)}/#{name_str}__-__#{page_str}.json"
    end
    
    def folder_number(page = 1)
      (page / Extraction::Documents::DOCUMENTS_PER_FOLDER.to_f).ceil
    end
  end
end
