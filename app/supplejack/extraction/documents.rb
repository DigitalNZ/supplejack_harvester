# frozen_string_literal: true

# Can be improved by using this: AbstractFactoryFactoryInterfaces
# or the iterator interface?

module Extraction
  # Currently used for the view to generate kaminari paginations
  class Documents
    attr_reader :current_page, :per_page, :limit_value

    def initialize(folder)
      @folder = folder
      @per_page = 1
      @limit_value = nil
      @documents = {}
    end

    def [](key)
      @current_page = key&.to_i || 1
      return nil unless in_bounds?(@current_page)

      @documents[@current_page] ||= Document.load_from_file(documents_filepath[@current_page - 1])
    end

    def total_pages
      documents_filepath.length
    end

    private

    def in_bounds?(current_page)
      current_page.in?(1..documents_filepath.length)
    end

    # The enrichments rely on the files being ordered by page number
    # so that the index [2005] gives back page 2005 etc.
    # If the pages and indexes do not match up, records will be enriched with data that is not meant for them
    def documents_filepath
      @documents_filepath ||= Dir.glob("#{@folder}/*.json").sort_by do |page|
        page.match(/__(?<record_id>.+)__(?<page>.+).json/)[:page].to_i
      end
    end
  end
end
