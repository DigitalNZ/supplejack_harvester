# frozen_string_literal: true

require 'nokogiri'
require 'jsonpath'

module Extraction
  class IndependentExtraction < AbstractExtraction
    def initialize(request, extraction_folder, page = 1, url_override = nil)
      super()
      @request = request
      @extraction_definition = request.extraction_definition
      @extraction_folder = extraction_folder
      @page = page
      @url_override = url_override
    end

    def extract
      ::Retriable.retriable { @document = fetch_document }
    rescue StandardError => e
      Rails.logger.info "Independent extraction error: #{e}"
    end

    def extract_links(selector)
      return [] if selector.blank? || @document&.body.blank?

      if selector.start_with?('$')
        extract_json_links(selector)
      elsif selector.start_with?('/')
        extract_xpath_links(selector)
      else
        extract_css_links(selector)
      end
    rescue JSON::ParserError, Nokogiri::SyntaxError
      []
    end

    def save_link(url, page_number, base_url)
      full_url = normalize_link_url(url, base_url)
      link_doc = Document.new(
        url: full_url, method: 'GET', params: {}, request_headers: {},
        status: 200, response_headers: {}, body: { url: full_url }.to_json
      )
      link_doc.save(link_file_path(page_number))
    end

    private

    def fetch_document
      if @extraction_definition.evaluate_javascript?
        JavascriptRequest.new(url:, params:).get
      else
        Request.new(url:, params:, headers:, method: http_method,
                    follow_redirects: @extraction_definition.follow_redirects).send(http_method)
      end
    end

    def url = @url_override || @request.url(nil)
    def params = @url_override.present? ? {} : @request.query_parameters(nil)
    def headers = @request.headers.blank? ? super : super.merge(@request.headers(nil))

    def file_path
      "#{@extraction_folder}/#{folder_number(@page)}/#{name_str}__-__#{page_str}.json"
    end

    def link_file_path(page_number)
      folder = (page_number / Documents::DOCUMENTS_PER_FOLDER.to_f).ceil
      "#{@extraction_folder}/#{folder}/#{name_str}__-__#{format('%09d', page_number)[-9..]}.json"
    end

    def name_str = @extraction_definition.name.parameterize(separator: '_')
    def page_str = format('%09d', @page)[-9..]

    def normalize_link_url(url, base_url)
      return url if url.start_with?('http://', 'https://')

      URI.join(base_url, url).to_s
    rescue URI::InvalidURIError
      url
    end

    # Link extraction methods

    def extract_json_links(selector)
      JsonPath.new(selector).on(JSON.parse(@document.body))
    end

    def extract_xpath_links(selector)
      parse_doc.xpath(selector).filter_map { |n| link_from_node(n) }.compact_blank
    end

    def extract_css_links(selector)
      parse_doc.css(selector).filter_map { |n| link_from_node(n) }.compact_blank
    end

    def parse_doc
      body = @document.body
      body.strip.start_with?('<?xml') ? Nokogiri::XML(body) : Nokogiri::HTML(body)
    end

    def link_from_node(node)
      case node
      when Nokogiri::XML::Attr then node.value
      when Nokogiri::XML::Element then node['href'] || node['url'] || node.text.strip.presence
      when Nokogiri::XML::Text then node.text.strip
      end
    end
  end
end
