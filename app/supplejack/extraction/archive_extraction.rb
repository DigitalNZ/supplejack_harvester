# frozen_string_literal: true

module Extraction
  class ArchiveExtraction < AbstractExtraction
    def initialize(request, extraction_folder = nil, response = nil)
      super()
      @request = request
      @extraction_folder = extraction_folder
      @response = response
      @document = nil
    end

    def download_archive
      extract
    end

    def save_entries(extraction_folder)
      each_entry(extraction_folder) do |_, name|
        current_document = build_doc("#{extraction_folder}/#{folder_number}/#{name}")
        save(current_document)
        next_page
      end
    ensure
      clear_extracted_archive(extraction_folder)
    end

    private

    def each_entry(extraction_folder)
      Minitar::Input.open(StringIO.new(@document.body)) do |input|
        input.each do |entry|
          input.extract_entry(extraction_folder, entry) do |action, name, stats|
            next if action != :file_done

            yield(action, name, stats)
          end
        end
      end
    end

    def clear_extracted_archive(extraction_folder)
      top_level_entries = []
      Minitar::Input.open(StringIO.new(@document.body)) do |input|
        top_level_entries = Archive.list_top_level_entries(input)
      end
      FileUtils.rm_rf(top_level_entries.compact_blank.map { |file| "#{extraction_folder}/#{file}" })
    end

    def build_doc(entry_path)
      Document.new(
        url: @document.url,
        method: @document.method,
        params: @document.params,
        request_headers: @document.request_headers,
        status: @document.status,
        response_headers: @document.response_headers,
        body: Archive.body(entry_path)
      )
    end

    def extraction_definition
      @request.extraction_definition
    end

    def next_page
      extraction_definition.page += 1
    end

    def save(doc)
      raise ArgumentError, 'extraction_folder was not provided in #new' if @extraction_folder.blank?
      raise '#extract must be called before #save AbstractExtraction' if @document.blank?

      doc.save(file_path)
    end

    def file_path
      page_str = format('%09d', extraction_definition.page)[-9..]
      name_str = extraction_definition.name.parameterize(separator: '_')
      "#{@extraction_folder}/#{folder_number}/#{name_str}__-__#{page_str}.json"
    end

    def folder_number
      ((extraction_definition.page || 1) / Documents::DOCUMENTS_PER_FOLDER.to_f).ceil
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
