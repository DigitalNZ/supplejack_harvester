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
      "#{job_folder(pipeline_job_id)}/#{position}"
    end

    # Every block's output for one pipeline job.
    def self.job_folder(pipeline_job_id)
      "#{FOLDER}/#{pipeline_job_id}"
    end

    # Pipeline job ids that have preprocess output on disk. Ignores anything
    # that is not a job id, since this walks a directory nobody owns.
    def self.pipeline_job_ids_on_disk
      Dir.children(FOLDER).grep(/\A\d+\z/).map(&:to_i)
    rescue Errno::ENOENT
      []
    end

    # Finds which pipeline jobs have written preprocess output for the given
    # block position, with a single disk walk rather than a per-job glob.
    def self.pipeline_job_ids_with_output(position)
      Dir.glob("#{FOLDER}/*/#{position}/**/*.json")
         .map { |path| path.delete_prefix("#{FOLDER}/").to_i }
         .uniq
    end

    def initialize(pipeline_job_id, position)
      @folder = self.class.folder(pipeline_job_id, position)
    end

    def write(records)
      write_page(next_page, records)
    end

    # Writes to an explicit page number instead of deriving it from a disk
    # count. TransformationWorker runs one Sidekiq job per page, potentially
    # concurrently, so callers that already know a unique page number (e.g.
    # the extraction page a given worker is handling) must use this instead
    # of #write to avoid two workers racing on the same computed next_page.
    def write_page(page, records)
      Extraction::Document.new(
        url: nil, method: 'GET', params: nil, request_headers: nil,
        status: 200, response_headers: nil,
        body: { records: records }.to_json
      ).save(file_path(page))
    end

    def documents
      Extraction::Documents.new(@folder)
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
