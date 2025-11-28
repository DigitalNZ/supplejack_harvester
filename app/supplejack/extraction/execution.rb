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
        Rails.logger.warn "No links extracted from pre-extraction document"
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
      pre_extraction_documents = pre_extraction_job.documents
      link_counter = 0
    
      (1..pre_extraction_documents.total_pages).each do |page_number|
        break if execution_cancelled?
    
        pre_extraction_doc = pre_extraction_documents[page_number]
        url = extract_url_from_pre_extraction_document(pre_extraction_doc)
        next if url.blank?
    
        request = build_request_for_url(url)
        
        # Fetch the document
        @de = DocumentExtraction.new(request, @extraction_job.extraction_folder, @previous_request)
        @previous_request = @de.extract
        
        # Skip this document if duplicate, but continue processing others
        next if duplicate_document_extracted?
        
        # Skip if document extraction failed
        next unless @de.document.present? && @de.document.successful?
        
        # Use job flag instead of definition flag
        if @extraction_job.pre_extraction?
          links = extract_links_from_document(@de.document)
          
          # Skip if no links found
          next if links.empty?
          
          links.each do |link_url|
            link_counter += 1
            save_link_as_document(link_url, link_counter)
            
            if @harvest_report.present?
              @harvest_report.increment_pages_extracted!
            end
          end
        else
          # Normal extraction - save the fetched document
          @de.save
          
          if @harvest_report.present?
            @harvest_report.increment_pages_extracted!
            @harvest_report.update(extraction_updated_time: Time.zone.now)
          end
          
          enqueue_record_transformation
        end
    
        throttle
      end
      
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
      return unless @harvest_job.present? && @de.document.successful?
      return if requires_additional_processing?

      TransformationWorker.perform_async_with_priority(@harvest_job.pipeline_job.job_priority, @harvest_job.id,
                                                       @extraction_definition.page)
      @harvest_report.increment_transformation_workers_queued!
    end

    def requires_additional_processing?
      @extraction_definition.split? || @extraction_definition.extract_text_from_file?
    end

    def extract_links_from_document(document)
      case @extraction_definition.format
      when 'JSON'
        extract_json_links(document.body)
      when 'XML'
        extract_xml_links(document.body)
      when 'HTML'
        extract_html_links(document.body)
      else
        []
      end
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
      doc.css('a[href]').map { |a| a['href'] }.compact
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
      document.body.strip
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
