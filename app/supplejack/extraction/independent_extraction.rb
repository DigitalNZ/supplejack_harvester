# frozen_string_literal: true

module Extraction
  class IndependentExtraction < DocumentExtraction
    def initialize(request, extraction_folder, page = 1, url_override = nil)
      super(request, extraction_folder)
      @page = page
      @url_override = url_override
    end

    private

    def url
      @url_override || super
    end

    def params
      @url_override.present? ? {} : super
    end

    def file_path
      page_str = format('%09d', @page)[-9..]
      name_str = @extraction_definition.name.parameterize(separator: '_')
      "#{@extraction_folder}/#{folder_number(@page)}/#{name_str}__-__#{page_str}.json"
    end
  end
end
