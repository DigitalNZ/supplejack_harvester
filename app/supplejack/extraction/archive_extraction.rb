# frozen_string_literal: true

module Extraction
  class ArchiveExtraction < AbstractExtraction
    def initialize(request, extraction_folder = nil, response = nil)
      super()
      @request = request
      @extraction_folder = extraction_folder
      @extraction_definition = request.extraction_definition
      @response = response
    end

    def download_archive
      extract
    end

    def save_entries(extraction_folder)
      each_entry(extraction_folder) do |_, name|
        @current_document = build_doc("#{extraction_folder}/#{name}")
        save
        next_page
      end
    ensure
      clear_extracted_archive(extraction_folder)
    end

    private

    def each_entry(extraction_folder)
      @top_level_entries = []
      Minitar::Input.open(StringIO.new(@document.body)) do |input|
        input.each do |entry|
          @top_level_entries << entry.full_name if top_level_entry?(entry.full_name)

          input.extract_entry(extraction_folder, entry) do |action, name, stats|
            next if action != :file_done

            yield(action, name, stats)
          end
        end
      end
    end

    def top_level_entry?(full_name)
      return true if full_name.count('/').zero?
      return true if full_name.count('/') == 1 && full_name[-1] == '/'

      false
    end

    def clear_extracted_archive(extraction_folder)
      FileUtils.rm_rf(@top_level_entries.compact_blank.map { |file| "#{extraction_folder}/#{file}" })
    end

    def build_doc(entry_path)
      Document.new(
        url: @document.url,
        method: @document.method,
        params: @document.params,
        request_headers: @document.request_headers,
        status: @document.status,
        response_headers: @document.response_headers,
        body: body(entry_path)
      )
    end

    def next_page
      @extraction_definition.page += 1
    end

    def save
      raise ArgumentError, 'extraction_folder was not provided in #new' if @extraction_folder.blank?
      raise '#extract must be called before #save AbstractExtraction' if @document.blank?

      @current_document.save(file_path)
    end

    def body(extracted_file_path)
      return extract_file_from_gz(extracted_file_path) if gzipped?(extracted_file_path)

      File.read(extracted_file_path)
    end

    def gzipped?(gz_file_path)
      File.open(gz_file_path, 'rb') do |file|
        magic_number = file.read(2).unpack('C2')
        return magic_number == [0x1F, 0x8B]
      end
    end

    def extract_file_from_gz(gz_path)
      body = Zlib::GzipReader.open(gz_path, &:read)
      File.delete(gz_path)
      body
    end

    def file_path
      page_str = format('%09d', @extraction_definition.page)[-9..]
      name_str = @extraction_definition.name.parameterize(separator: '_')
      "#{@extraction_folder}/#{name_str}__-__#{page_str}.json"
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
