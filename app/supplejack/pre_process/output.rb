# frozen_string_literal: true

module PreProcess
  # Writes a preprocess block's transformed records to disk so the next block
  # can iterate them. Records are stored as {"records":[…]} documents in the
  # Extraction::Documents on-disk layout (100 documents per folder), which the
  # existing document reader and enrichment page-processing code consume as-is.
  class Output
    FOLDER = Rails.root.join("extractions/#{Rails.env}/preprocess").to_s
    DOCUMENTS_PER_FOLDER = 100

    def self.folder(pipeline_job_id, position)
      "#{FOLDER}/#{pipeline_job_id}/#{position}"
    end

    def initialize(pipeline_job_id, position)
      @folder = self.class.folder(pipeline_job_id, position)
    end

    def write(records)
      page = next_page
      Extraction::Document.new(
        url: nil, method: 'GET', params: nil, request_headers: nil,
        status: 200, response_headers: nil,
        body: { records: records }.to_json
      ).save(file_path(page))
    end

    private

    def next_page
      Dir.glob("#{@folder}/**/*.json").count + 1
    end

    def file_path(page)
      folder_number = (page / DOCUMENTS_PER_FOLDER.to_f).ceil
      page_str = format('%09d', page)[-9..]
      "#{@folder}/#{folder_number}/preprocess__#{page_str}.json"
    end
  end
end
