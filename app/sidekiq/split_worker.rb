# frozen_string_literal: true

class SplitWorker < FileExtractionWorker
  def process_extracted_documents
    Dir.children(@tmp_directory).each do |folder|
      process_folder(folder)
    end
  end

  def process_folder(folder)
    Dir.children("#{@tmp_directory}/#{folder}").each do |file|
      process_file(folder, file)
    end
  rescue StandardError => e
    handle_split_error(e)
  end

  def process_file(folder, file)
    saved_response = JSON.parse(File.read("#{@tmp_directory}/#{folder}/#{file}"))
    process_xml_records(saved_response)
  end

  def process_xml_records(saved_response)
    Nokogiri::XML(saved_response['body']).xpath(@extraction_definition.split_selector).each_slice(100) do |records|
      create_document(records, saved_response)
      @page += 1
    end
  end

  def handle_split_error(error)
    JobCompletion::Logger.log_completion(
      origin: 'SplitWorker',
      error: error,
      definition: @extraction_definition,
      job: @extraction_job,
      details: {}
    )
    raise
  end

  private

  def create_document(records, saved_response)
    page_str = format('%09d', @page)[-9..]
    name_str = @extraction_definition.name.parameterize(separator: '_')

    Extraction::Document.new(
      url: saved_response['url'], method: saved_response['method'],
      params: saved_response['params'], request_headers: saved_response['request_headers'],
      status: saved_response['status'], response_headers: saved_response['response_headers'],
      body: "<?xml version=\"1.0\"?><root><records>#{records.map(&:to_xml).join}</records></root>"
    ).save("#{@extraction_folder}/#{folder_number(@page)}/#{name_str}__-__#{page_str}.json")
  end
end
