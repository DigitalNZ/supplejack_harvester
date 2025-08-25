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
      if documents_filepath.blank?
        return @documents[@current_page] =
                 Document.new(documents_filepath, body: '{"message":"File does not exist in filesystem"}')
      end

      @documents[@current_page] = Document.load_from_file(documents_filepath)
    end

    def total_pages
      return 0 if total_folders.zero?

      ((total_folders - 1) * DOCUMENTS_PER_FOLDER) + Dir.glob("#{@folder}/#{total_folders}/*").count
    end

    def total_folders
      Dir.children(@folder).count { |f| !f.ends_with?('tmp') }
    rescue Errno::ENOENT # folder does not exist
      0
    end

    private

    def documents_filepath
      folder_number = folder_number(@current_page)
      page_number = format('%09d', @current_page)[-9..]
      @documents_filepath = Dir.glob("#{@folder}/#{folder_number}/*__#{page_number}.json").first
    end

    def folder_number(page = 1)
      (page / DOCUMENTS_PER_FOLDER.to_f).ceil
    end
  end
end
