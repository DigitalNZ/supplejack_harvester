# frozen_string_literal: true

# Can be improved by using this: AbstractFactoryFactoryInterfaces
# or the iterator interface?

module Extraction
  # Currently used for the view to generate kaminari paginations
  class Documents
    DOCUMENTS_PER_FOLDER = 100
    attr_reader :current_page, :per_page, :limit_value

    def initialize(folder)
      @folder = folder
      @per_page = 1
      @limit_value = nil
      @documents = {}
    end

    def [](key)
      @current_page = key&.to_i || 1
      return nil unless documents_filepath.present?

      @documents[@current_page] = Document.load_from_file(documents_filepath)
    end

    def total_pages
      ((total_folders.size - 1) * DOCUMENTS_PER_FOLDER) + Dir.glob("#{@folder}/#{total_folders.size}/*").size
    end

    def total_folders
      Dir.glob("#{@folder}/*")
    end

    private

    def documents_filepath
      @documents_filepath = Dir.glob("#{@folder}/#{folder_number}/*__#{format('%09d', @current_page)[-9..]}.json").first
    end

    def folder_number
      ((@current_page || 1) / DOCUMENTS_PER_FOLDER.to_f).ceil
    end
  end
end
