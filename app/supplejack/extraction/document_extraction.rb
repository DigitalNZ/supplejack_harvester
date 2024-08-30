# frozen_string_literal: true

module Extraction
  class DocumentExtraction < AbstractExtraction
    def initialize(request, extraction_folder = nil, response = nil)
      super()
      @request = request
      @extraction_folder = extraction_folder
      @extraction_definition = request.extraction_definition
      @response = response
    end

    def extract
      ::Retriable.retriable do
        @document = if @extraction_definition.evaluate_javascript?
                      Extraction::JavascriptRequest.new(url:, params:).get
                    else
                      Extraction::Request.new(url:, params:, headers:).send(http_method)
                    end
      end
    rescue StandardError => e
      ::Sidekiq.logger.info "Extraction error: #{e}" if defined?(Sidekiq)
    end

    private

    def file_path
      page_str = format('%09d', @extraction_definition.page)[-9..]
      name_str = @extraction_definition.name.parameterize(separator: '_')
      "#{@extraction_folder}/#{folder_number(@extraction_definition.page)}/#{name_str}__-__#{page_str}.json"
    end

    def url
      @request.url(@response)
    end

    def params
      @request.query_parameters(@response)
    end

    def headers
      return super if @request.headers.blank?

      super.merge(@request.headers(@response))
    end
  end
end
