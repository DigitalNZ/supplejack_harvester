# frozen_string_literal: true

class TextExtractionWorker < FileExtractionWorker
  def process_extracted_documents
    Dir.children(@tmp_directory).each do |file|
      saved_file = File.read("#{@tmp_directory}/#{file}")

      saved_response = { 'method' => 'GET', 'status' => 200, 'response_headers' => [], 'request_headers' => [] }

      create_document(Yomu.read(:text, saved_file), saved_response, file)
      @page += 1
    end

    @extraction_definition.update(format: 'JSON')
  end

  def create_document(extracted_text, saved_response, filename)
    Extraction::Document.new(
      url: saved_response['url'], method: saved_response['method'],
      params: saved_response['params'], request_headers: saved_response['request_headers'],
      status: saved_response['status'], response_headers: saved_response['response_headers'],
      body: { text: extracted_text }.to_json
    ).save("#{@extraction_folder}/#{filename}")
  end
end
