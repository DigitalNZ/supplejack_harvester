# frozen_string_literal: true

require 'securerandom'

# rails "s3:extract[bucket_source]"

namespace :s3 do
  ## EXAMPLE
  # extraction_definition = The extraction definition to associate the result of the S3 extraction with
  # S3ExtractionExecution.new(extraction_definition.id, "#{args[:source]}/FOLDER_NAME", 'file-pattern').call

  task :extract, [:source] => [:environment] do |_task, args|

    historic_harvest = HarvestDefinition.find_by(source_id: "historic-legislation")

    p "Extracting Historic Legislation..."
    S3ExtractionExecution.new(historic_harvest.extraction_definition.id, "",
      "").call
  end
end

class S3ExtractionExecution
  def initialize(extraction_definition_id, source, file_pattern)
    @extraction_definition = ExtractionDefinition.find(extraction_definition_id)
    @source = source
    @file_pattern = file_pattern
    @extraction_job = ExtractionJob.create(extraction_definition: @extraction_definition)
  end

  def call
    initialize_folder_structure
    sync_files
    convert_files_to_extraction_job
    p 'Complete!'
  end

  private

  def initialize_folder_structure
    p 'Initializing folder structure...'

    @directory_path = "./extractions/#{Rails.env}/s3"
    @job_id = SecureRandom.hex

    FileUtils.mkdir_p("#{@directory_path}/#{@job_id}")
  end

  def sync_files
    p 'Syncing files from S3...'

    `aws s3 sync '#{@source}' '#{@directory_path}/#{@job_id}' --exclude '*' --include '#{@file_pattern}'`
  end

  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/AbcSize
  def convert_files_to_extraction_job
    p 'Converting files from S3 into extraction job format...'

    page = 1
    
    Dir["#{@directory_path}/#{@job_id}/**/*.xml"].each_slice(Extraction::Documents::DOCUMENTS_PER_FOLDER).with_index do |batch, index|
      page_str = format('%09d', page)[-9..]
      name_str = @extraction_definition.name.parameterize(separator: '_')

      files = batch.map { |file| File.read(file) }
      metadata = files.map { |record| Nokogiri::HTML(record).xpath('/html/body/metadata') }
      body = "<?xml version=\"1.0\"?><root>#{metadata.map(&:to_xml).join}</root>"

      Extraction::Document.new(
        url: 's3', method: 's3 cli',
        params: '', request_headers: [],
        status: '', response_headers: [],
        body:
      ).save("#{@extraction_job.extraction_folder}/#{folder_number(index + 1)}/#{name_str}__-__#{page_str}.json")

      page += 1
    end

    @extraction_job.completed!
  end

  def folder_number(page = 1)
    (page / Extraction::Documents::DOCUMENTS_PER_FOLDER.to_f).ceil
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength
end
