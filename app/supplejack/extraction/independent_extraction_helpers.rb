# frozen_string_literal: true

module Extraction
  # rubocop:disable Metrics/ModuleLength
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
        perform_link_extraction_from_documents(documents)
      else
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
      links = []
      (1..documents.total_pages).each do |page_number|
        break if execution_cancelled?

        extracted = extract_links_from_link_document(documents[page_number])
        links.concat(extracted) if extracted
      end
      links
    end

    # This is used when one independent extraction is passed a "link" document
    # processing output from a previous independent extraction, not a webpage
    def extract_links_from_link_document(doc)
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

    # --- Link extraction ---

    # this is used to extract links from an HTML/XML document (a page)
    def extract_links_from_document(document)
      selector = find_link_selector
      return [] if selector.blank?

      if selector.start_with?('$')
        extract_json_links(document.body, selector)
      else
        extract_html_links(document.body, selector)
      end
    end

    def extract_json_links(body, selector)
      parsed = JSON.parse(body)
      JsonPath.new(selector).on(parsed)
    rescue JSON::ParserError
      []
    end

    def extract_html_links(body, selector)
      doc = body.strip.start_with?('<?xml') ? Nokogiri::XML(body) : Nokogiri::HTML(body)
      nodes = selector.start_with?('/') ? doc.xpath(selector) : doc.css(selector)
      nodes.filter_map { |node| extract_link_from_node(node) }.compact_blank
    rescue Nokogiri::SyntaxError
      []
    end

    def extract_link_from_node(node)
      case node
      when Nokogiri::XML::Attr then node.value
      when Nokogiri::XML::Element then node['href'] || node['url'] || node.text.strip.presence
      when Nokogiri::XML::Text then node.text.strip
      else node.to_s
      end
    end

    def find_link_selector
      automation_step = find_automation_step_for_job
      automation_step&.link_selector
    end

    def find_automation_step_for_job
      AutomationStep.find_by(independent_extraction_job_id: @extraction_job.id)
    end

    # --- Document type detection ---

    def independent_extraction_link_document?(document)
      return false unless document

      body = JSON.parse(document.body)
      body.is_a?(Hash) && body.key?('url') && body.keys.size == 1
    rescue JSON::ParserError
      false
    end

    def extract_url_from_independent_extraction_document(document)
      body = JSON.parse(document.body)
      body['url'] || body['href'] || body['link']
    rescue JSON::ParserError
      nil
    end

    # --- Request building ---

    # rubocop:disable Rails/Delegate
    def build_request_for_url(url)
      base_request = @extraction_definition.requests.first

      Struct.new(:base_request, :override_url) do
        def url(_response = nil) = override_url
        def query_parameters(response = nil) = base_request.query_parameters(response)
        def headers(response = nil) = base_request.headers(response)
        def extraction_definition = base_request.extraction_definition
        def http_method = base_request.http_method
      end.new(base_request, url)
    end
    # rubocop:enable Rails/Delegate

    # --- Document saving ---

    def save_link_as_document(link_url, page_number, folder = nil)
      full_url = normalize_url(link_url)
      link_document = build_link_document(full_url)
      link_document.save(file_path_for_page(page_number, folder))
    end

    def build_link_document(url)
      Extraction::Document.new(
        url:, method: 'GET', params: {}, request_headers: {},
        status: 200, response_headers: {}, body: { url: }.to_json
      )
    end

    def normalize_url(url)
      return url if url.start_with?('http://', 'https://')

      base_uri = URI.parse(@extraction_definition.base_url)
      URI.join(base_uri, url).to_s
    rescue URI::InvalidURIError
      url
    end

    def file_path_for_page(page_number, folder = nil)
      page_str = format('%09d', page_number)[-9..]
      name_str = @extraction_definition.name.parameterize(separator: '_')
      target_folder = folder || @extraction_job.extraction_folder
      "#{target_folder}/#{calculate_folder_number(page_number)}/#{name_str}__-__#{page_str}.json"
    end

    def calculate_folder_number(page = 1)
      (page / Extraction::Documents::DOCUMENTS_PER_FOLDER.to_f).ceil
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
