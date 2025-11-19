# frozen_string_literal: true

class MultiItemExtractionService
  def self.extract_items_from_document(document, extraction_definition)
    new(document, extraction_definition).extract_items
  end

  def initialize(document, extraction_definition)
    @document = document
    @extraction_definition = extraction_definition
  end

  def extract_items
    format = determine_format
    case format
    when 'html'
      extract_html_items
    when 'xml'
      extract_xml_items
    when 'json'
      extract_json_items
    else
      []
    end
  end

  private

  def determine_format
    if @extraction_definition.respond_to?(:item_extraction_format) &&
       @extraction_definition.item_extraction_format.present? &&
       @extraction_definition.item_extraction_format != 'auto'
      return @extraction_definition.item_extraction_format
    end

    # Fallback to link_extraction_format for backward compatibility
    if @extraction_definition.respond_to?(:link_extraction_format) &&
       @extraction_definition.link_extraction_format.present? &&
       @extraction_definition.link_extraction_format != 'auto'
      return @extraction_definition.link_extraction_format
    end

    # Auto-detect
    case @extraction_definition.format
    when 'HTML'
      'html'
    when 'XML'
      'xml'
    when 'JSON', 'ARCHIVE_JSON'
      'json'
    else
      detect_format_from_content(@document.body)
    end
  end

  def detect_format_from_content(body)
    return 'json' if body.strip.start_with?('{', '[')
    return 'xml' if body.strip.start_with?('<?xml', '<')

    'html'
  end

  def extract_html_items
    selector = get_item_selector
    return [] unless selector.present?

    doc = Nokogiri::HTML(@document.body)
    if selector.start_with?('/')
      # XPath
      doc.xpath(selector).map { |el| extract_item_value(el) }
    else
      # CSS selector
      doc.css(selector).map { |el| extract_item_value(el) }
    end
  end

  def extract_xml_items
    selector = get_item_selector
    return [] unless selector.present?

    doc = Nokogiri::XML(@document.body)
    doc.xpath(selector).map { |el| extract_item_value(el) }
  end

  def extract_json_items
    selector = get_item_selector
    return [] unless selector.present?

    json_data = JSON.parse(@document.body)
    JsonPath.new(selector).on(json_data).flatten.map { |item| normalize_item(item) }
  rescue JSON::ParserError
    []
  end

  def get_item_selector
    # Try new field name first
    return @extraction_definition.item_selector if @extraction_definition.respond_to?(:item_selector) && @extraction_definition.item_selector.present?
    
    # Fallback to old field name for backward compatibility
    return @extraction_definition.link_selector if @extraction_definition.respond_to?(:link_selector) && @extraction_definition.link_selector.present?
    
    nil
  end

  def extract_item_value(element)
    # For URLs, get href/src attribute or text
    # For other data, get text or serialize
    url = if element.respond_to?(:[])
            element['href'] || element['src'] || element.text
          else
            element.text
          end
    normalize_url(url.to_s.strip)
  end

  def normalize_item(item)
    # Normalize URLs, convert to strings, etc.
    case item
    when Hash, Array
      item.to_json  # For complex data
    else
      normalize_url(item.to_s)
    end
  end

  def normalize_url(url)
    return nil if url.blank?

    # Convert relative URLs to absolute (if we have a base URL)
    begin
      uri = URI.parse(url)
      if uri.relative? && @document.url.present?
        base_uri = URI.parse(@document.url)
        uri = base_uri + url
      end
      uri.to_s
    rescue URI::InvalidURIError
      nil
    end
  end
end

