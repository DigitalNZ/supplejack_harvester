# frozen_string_literal: true

require 'json'
require 'jsonpath'
require 'nokogiri'

module Extraction
  # Service object for extracting links from documents
  # Handles JSON, XML, and HTML formats with configurable selectors
  # rubocop:disable Metrics/ClassLength
  class LinkExtractor
    def initialize(document, extraction_definition)
      @document = document
      @extraction_definition = extraction_definition
      @body = document.body
      @stripped_body = @body.strip
      @selector = nil
      @current_node = nil
    end

    def extract(depth = 1)
      format = detect_format
      @selector = @extraction_definition.link_selector_for_depth(depth)

      return [] if @selector.blank?

      extract_by_format(format, depth)
    end

    private

    def detect_format
      original_format = @extraction_definition.format

      case original_format
      when 'JSON' then json_format? ? original_format : detect_from_content
      when 'XML' then xml_start? ? original_format : detect_from_content
      when 'HTML' then detect_html_format(original_format)
      else original_format
      end
    end

    def detect_html_format(original_format)
      return 'XML' if xml_sitemap?
      return detect_from_content unless html_content?

      original_format
    end

    def detect_from_content
      return 'XML' if xml_format?
      return 'JSON' if json_format?
      return 'HTML' if html_format?

      'HTML'
    end

    def json_format?
      @stripped_body.start_with?('{', '[')
    end

    def xml_start?
      @stripped_body.start_with?('<?xml', '<')
    end

    def xml_format?
      @stripped_body.start_with?('<?xml') ||
        (@stripped_body.start_with?('<') && @stripped_body.include?('<?xml'))
    end

    def html_format?
      @stripped_body.include?('<html') || @stripped_body.include?('<!DOCTYPE') || @stripped_body.include?('<')
    end

    def xml_sitemap?
      @stripped_body.start_with?('<?xml') ||
        (@stripped_body.start_with?('<') && (@body.include?('<urlset') || @body.include?('<sitemap')))
    end

    def html_content?
      @body.include?('<html') || @body.include?('<!DOCTYPE') || @body.include?('<')
    end

    def extract_by_format(format, depth)
      @format = format
      case format
      when 'JSON' then extract_json_links(depth)
      when 'XML' then extract_xml_links
      when 'HTML' then extract_html_links
      else []
      end
    end

    def extract_json_links(depth)
      parsed = JSON.parse(@body)
      selector = @extraction_definition.link_selector_for_depth(depth)

      return [] if selector.blank?

      JsonPath.new(selector).on(parsed)
    rescue JSON::ParserError
      []
    end

    def extract_xml_links
      doc = Nokogiri::XML.parse(@body)
      extract_xml_nodes(doc)
    rescue Nokogiri::XML::SyntaxError
      []
    end

    def extract_xml_nodes(doc)
      nodes = @selector.start_with?('/') ? doc.xpath(@selector) : doc.css(@selector)
      nodes.filter_map { |node| node['href'] || node['url'] || node.text }
    end

    def extract_html_links
      doc = Nokogiri::HTML.parse(@body)
      extract_links_with_selector(doc)
    rescue Nokogiri::SyntaxError, StandardError
      []
    end

    def extract_links_with_selector(doc)
      if @selector.start_with?('/')
        extract_xpath_links(doc)
      else
        extract_css_links(doc)
      end
    end

    def extract_xpath_links(doc)
      matched_nodes = doc.xpath(@selector)
      matched_nodes.filter_map { |node| extract_link_from_node(node) }.compact_blank
    end

    def extract_css_links(doc)
      doc.css(@selector).filter_map { |node| node['href'] || node['url'] || node.text }.compact_blank
    end

    def extract_link_from_node(node)
      @current_node = node
      case node
      when Nokogiri::XML::Attr then node.value
      when Nokogiri::XML::Element then extract_link_from_element
      when Nokogiri::XML::Text then extract_link_from_text_node
      else extract_link_fallback
      end
    end

    def extract_link_from_element
      href = @current_node['href'] || @current_node['url']
      return href if href.present?

      @current_node.text.strip.presence
    end

    def extract_link_from_text_node
      node_text = @current_node.text.strip
      parent = @current_node.parent
      return parent['href'] || node_text if parent&.name == 'a'

      node_text
    end

    def extract_link_fallback
      if @current_node.respond_to?(:[])
        @current_node['href'] || @current_node['url'] || @current_node.text
      else
        @current_node.to_s
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
