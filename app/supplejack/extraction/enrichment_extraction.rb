# frozen_string_literal: true

module Extraction
  class EnrichmentExtraction < AbstractExtraction
    def initialize(request, record, page = 1, extraction_folder = nil)
      super()
      @request = request
      @extraction_definition = request.extraction_definition
      @record = record
      @page = page
      @extraction_folder = extraction_folder
    end

    def extract
      ensure_requestable_url

      ::Retriable.retriable { @document = fetch_document }
    rescue StandardError => e
      @extraction_error = e
      ::Sidekiq.logger.info "Extraction error: #{e}" if defined?(Sidekiq)
    end

    def valid?
      url.exclude?('evaluation-error')
    end

    private

    def fetch_document
      return Extraction::JavascriptRequest.new(url:, params:).get if @extraction_definition.evaluate_javascript?

      Extraction::Request.new(url:, params:, headers:, method: http_method,
                              follow_redirects: @extraction_definition.follow_redirects).send(http_method)
    end

    def url
      return fragment_url if @extraction_definition.fragment_source_id.present?

      @request.url(@record)
    end

    def params
      return {} if @extraction_definition.fragment_source_id.present?

      @request.query_parameters(@record)
    end

    def headers
      return super if @request.headers.blank?

      super.merge(@request.headers(@response))
    end

    def file_path
      name_str = @extraction_definition.name.parameterize(separator: '_')
      page_str = format('%09d', @page)[-9..]
      "#{@extraction_folder}/#{folder_number(@page)}/#{name_str}__#{@record['id']}__#{page_str}.json"
    end

    def fragment_url
      url = @record['fragments'].find do |fragment|
              fragment['source_id'] == @extraction_definition.fragment_source_id
            end[@extraction_definition.fragment_key]

      [*url].first
    end
  end
end
