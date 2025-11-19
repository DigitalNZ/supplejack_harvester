# frozen_string_literal: true

class LinkExtractionService
  def self.extract_links(source_extraction_job, extraction_definition)
    new(source_extraction_job, extraction_definition).extract_links
  end

  def initialize(source_extraction_job, extraction_definition)
    @source_extraction_job = source_extraction_job
    @extraction_definition = extraction_definition
    # Use source extraction's base_url for URL normalization
    @base_url = source_extraction_job.extraction_definition.base_url
  end

  def extract_links
    Rails.logger.info "[LinkExtractionService] Starting link extraction from extraction_job #{@source_extraction_job.id}"
    Rails.logger.info "[LinkExtractionService] Link selector: #{get_link_selector}, format: #{@extraction_definition.link_extraction_format}"
    
    links = []
    document_count = 0
    @source_extraction_job.documents.each do |document_path|
      document_count += 1
      Rails.logger.info "[LinkExtractionService] Processing document #{document_count}: #{document_path}"
      
      document = Extraction::Document.load_from_file(document_path)
      unless document.is_a?(Extraction::Document) && document.body.present?
        Rails.logger.warn "[LinkExtractionService] Skipping document #{document_count}: not a valid document or body is empty"
        next
      end

      Rails.logger.info "[LinkExtractionService] Document body length: #{document.body.length} characters"
      Rails.logger.info "[LinkExtractionService] Document body preview: #{document.body[0..200]}..."
      
      extracted_links = extract_links_from_document(document)
      Rails.logger.info "[LinkExtractionService] Extracted #{extracted_links.count} links from document #{document_count}"
      if extracted_links.any?
        Rails.logger.info "[LinkExtractionService] Links from document #{document_count}: #{extracted_links.first(3).inspect}"
      end
      links.concat(extracted_links)
    end
    
    unique_links = links.uniq.compact
    Rails.logger.info "[LinkExtractionService] Total links extracted: #{links.count}, unique: #{unique_links.count}"
    unique_links
  end

  private

  def extract_links_from_document(document)
    format = determine_format(document)
    Rails.logger.info "[LinkExtractionService] Determined format: #{format} for document"
    
    case format
    when 'html'
      extract_html_links(document.body)
    when 'xml'
      extract_xml_links(document.body)
    when 'json'
      extract_json_links(document.body)
    else
      Rails.logger.warn "[LinkExtractionService] Unknown format: #{format}, returning empty array"
      []
    end
  end

  def determine_format(document)
    # Check if link_extraction_format field exists and is set
    if @extraction_definition.respond_to?(:link_extraction_format) &&
       @extraction_definition.link_extraction_format.present? &&
       @extraction_definition.link_extraction_format != 'auto'
      return @extraction_definition.link_extraction_format
    end

    # Auto-detect based on extraction definition format
    case @extraction_definition.format
    when 'HTML'
      'html'
    when 'XML'
      'xml'
    when 'JSON', 'ARCHIVE_JSON'
      'json'
    else
      # Try to detect from content
      detect_format_from_content(document.body)
    end
  end

  def detect_format_from_content(body)
    return 'json' if body.strip.start_with?('{', '[')
    return 'xml' if body.strip.start_with?('<?xml', '<')

    'html'
  end

  def extract_html_links(body)
    selector = get_link_selector
    return [] unless selector.present?

    doc = Nokogiri::HTML(body)
    # Support both CSS selectors and XPath
    if selector.start_with?('/')
      # XPath
      doc.xpath(selector).map do |element|
        extract_url_from_element(element, 'href')
      end
    else
      # CSS selector
      doc.css(selector).map do |element|
        extract_url_from_element(element, 'href')
      end
    end
  end

  def extract_xml_links(body)
    selector = get_link_selector
    unless selector.present?
      Rails.logger.warn "[LinkExtractionService] No link selector provided for XML extraction"
      return []
    end

    Rails.logger.info "[LinkExtractionService] Extracting XML links with selector: #{selector}"
    doc = Nokogiri::XML(body)
    
    elements = doc.xpath(selector)
    Rails.logger.info "[LinkExtractionService] Found #{elements.count} elements matching XPath: #{selector}"
    
    if elements.empty?
      Rails.logger.warn "[LinkExtractionService] No elements found with XPath: #{selector}"
      Rails.logger.warn "[LinkExtractionService] XML preview: #{body[0..500]}..."
    end
    
    links = elements.map do |element|
      url = element.text.strip
      Rails.logger.debug "[LinkExtractionService] Extracted text from element: #{url[0..100]}"
      normalized = normalize_url(url)
      Rails.logger.debug "[LinkExtractionService] Normalized URL: #{normalized}"
      normalized
    end
    
    Rails.logger.info "[LinkExtractionService] Extracted #{links.compact.count} valid URLs from #{elements.count} elements"
    links
  end

  def extract_json_links(body)
    selector = get_link_selector
    return [] unless selector.present?

    json_data = JSON.parse(body)
    JsonPath.new(selector).on(json_data).flatten.map do |url|
      normalize_url(url.to_s)
    end
  rescue JSON::ParserError
    []
  end

  def get_link_selector
    return nil unless @extraction_definition.respond_to?(:link_selector)

    @extraction_definition.link_selector
  end

  def extract_url_from_element(element, attribute = 'href')
    url = if element.respond_to?(:[])
            element[attribute] || element.text
          else
            element.text
          end
    normalize_url(url.to_s.strip)
  end

  def normalize_url(url)
    return nil if url.blank?

    # Convert relative URLs to absolute
    begin
      uri = URI.parse(url)
      if uri.relative?
        base_uri = URI.parse(@base_url)
        uri = base_uri + url
      end
      uri.to_s
    rescue URI::InvalidURIError
      nil
    end
  end
end

