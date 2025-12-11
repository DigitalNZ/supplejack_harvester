# frozen_string_literal: true

require 'json'
require 'jsonpath'
require 'nokogiri'

module Extraction
  # Extracts links from documents using configurable selectors
  class LinkExtractor
    def initialize(document, selector)
      @body = document.body
      @selector = selector
    end

    def extract
      return [] if @selector.blank?

      if @selector.start_with?('$')
        extract_json_links(@selector)
      else
        extract_document_links(@selector)
      end
    end

    private

    def extract_json_links(selector)
      parsed = JSON.parse(@body)
      JsonPath.new(selector).on(parsed)
    rescue JSON::ParserError
      []
    end

    def extract_document_links(selector)
      doc = parse_document
      nodes = selector.start_with?('/') ? doc.xpath(selector) : doc.css(selector)
      nodes.filter_map { |node| extract_link_from_node(node) }.compact_blank
    rescue Nokogiri::SyntaxError
      []
    end

    def parse_document
      @body.strip.start_with?('<?xml') ? Nokogiri::XML(@body) : Nokogiri::HTML(@body)
    end

    def extract_link_from_node(node)
      case node
      when Nokogiri::XML::Attr then node.value
      when Nokogiri::XML::Element then node['href'] || node['url'] || node.text.strip.presence
      when Nokogiri::XML::Text then node.text.strip
      else node.to_s
      end
    end
  end
end
