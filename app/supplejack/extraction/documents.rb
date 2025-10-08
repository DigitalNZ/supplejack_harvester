# frozen_string_literal: true

# Can be improved by using this: AbstractFactoryFactoryInterfaces
# or the iterator interface?

module Extraction
  # Currently used for the view to generate kaminari paginations
  class Documents
    DOCUMENTS_PER_FOLDER = 100

    attr_reader :current_page, :per_page, :limit_value, :total_folders

    def initialize(folder)
      @folder = folder
      @per_page = 1
      @limit_value = nil
      @documents = {}
      @folder_cache = {}
      @file_cache = {}

      preload_folder_structure
    end

    def [](key)
      @current_page = key&.to_i || 1
      return @documents[@current_page] if @documents.key?(@current_page)

      filepath = @file_cache[@current_page]

      unless filepath && File.exist?(filepath)
        return @documents[@current_page] = Document.new(nil, body: '{"message":"File does not exist in filesystem"}')
      end

      @documents[@current_page] = Document.load_from_file(filepath)
    end

    def total_pages
      return 0 if @total_folders.zero?

      # Fast lookup for last folder contents
      last_folder_number = @total_folders
      last_folder_files = @folder_cache[last_folder_number] || []
      ((@total_folders - 1) * DOCUMENTS_PER_FOLDER) + last_folder_files.count
    end

    private

    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/AbcSize
    def preload_folder_structure
      @total_folders = 0

      Dir.each_child(@folder) do |folder_name|
        next if folder_name.end_with?('tmp')

        folder_path = File.join(@folder, folder_name)
        next unless File.directory?(folder_path)

        folder_num = folder_name.to_i
        @folder_cache[folder_num] = Dir.children(folder_path).select { |f| f.end_with?('.json') }.map do |f|
          file_path = File.join(folder_path, f)

          # Extract the page number from the filename (e.g., something__000000123.json)
          if f =~ /__(\d+)\.json$/
            page_number = ::Regexp.last_match(1).to_i
            @file_cache[page_number] = file_path
          end

          file_path
        end

        @total_folders += 1
      end
    rescue Errno::ENOENT
      @total_folders = 0
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/AbcSize
  end
end
