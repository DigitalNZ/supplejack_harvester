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
      ::Retriable.retriable do
        @document = if @extraction_definition.evaluate_javascript?
                      Extraction::JavascriptRequest.new(url:, params:).get
                    else
                      Extraction::Request.new(url:, params:, headers:, method: http_method).send(http_method)
                    end
      end
    rescue StandardError => e
      ::Sidekiq.logger.info "Extraction error: #{e}" if defined?(Sidekiq)
    end

    def valid?
      url.exclude?('evaluation-error')
    end

    private

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
