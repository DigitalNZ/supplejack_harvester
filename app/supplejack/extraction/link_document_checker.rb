# frozen_string_literal: true

require 'json'
require 'nokogiri'

module Extraction
  # Service object for checking if a document body contains pre-extraction link flags
  class LinkDocumentChecker
    PRE_EXTRACTION_KEY = 'pre_extraction_link'

    def initialize(body)
      @body = body
      @body_str = body.to_s
      @parsed_json = nil
    end

    def link_document?
      return false unless @body

      return check_hash if @body.is_a?(Hash)

      check_string
    end

    private

    def check_hash
      @body[PRE_EXTRACTION_KEY] == true || @body[PRE_EXTRACTION_KEY.to_sym] == true
    end

    def check_string
      return true if contains_link_flag_literal?
      return true if json_contains_link_flag?
      return true if html_contains_link_flag?

      false
    end

    def contains_link_flag_literal?
      @body_str.include?('"pre_extraction_link":true') ||
        @body_str.include?("'pre_extraction_link':true")
    end

    def json_contains_link_flag?
      @parsed_json = JSON.parse(@body_str)
      parsed_json_has_link_flag?
    rescue JSON::ParserError
      false
    end

    def parsed_json_has_link_flag?
      @parsed_json.is_a?(Hash) && @parsed_json[PRE_EXTRACTION_KEY] == true
    end

    def html_contains_link_flag?
      return false unless @body_str.strip.start_with?('<')
      return true if json_pattern_in_html?

      extract_and_check_json_from_html
    rescue Nokogiri::SyntaxError, JSON::ParserError
      false
    end

    def json_pattern_in_html?
      /\{"url":.*"pre_extraction_link":\s*true\}/.match?(@body_str)
    end

    def extract_and_check_json_from_html
      doc = Nokogiri::HTML.parse(@body_str)
      text_content = doc.text.strip
      return false unless text_content.start_with?('{')

      @parsed_json = JSON.parse(text_content)
      parsed_json_has_link_flag?
    rescue StandardError
      false
    end
  end
end
