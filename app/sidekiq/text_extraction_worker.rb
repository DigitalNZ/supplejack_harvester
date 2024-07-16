# frozen_string_literal: true

class TextExtractionWorker < FileExtractionWorker
  def process_extracted_documents
    Dir.children(@tmp_directory).each do |file|
      saved_file = File.read("#{@tmp_directory}/#{file}")
      mimetype = Marcel::MimeType.for(saved_file)

      saved_response = { 'method' => 'GET', 'status' => 200, 'response_headers' => [], 'request_headers' => [] }
      text = Yomu.read(:text, saved_file)
      process = "Extracted from #{mimetype} using Yomu"

      if text.squish.empty?
        base_file_name = File.basename(file, File.extname(file))
        `ocrmypdf "#{@tmp_directory}/#{file}" --sidecar "#{@tmp_directory}/#{base_file_name}.txt" - --output-type=none -q`
        text = File.read("#{@tmp_directory}/#{base_file_name}.txt")
        process = 'Extracted from PDF using OCRmyPDF'
      end

      create_document(text, saved_response, file, process)
      @page += 1
    end

    @extraction_definition.update(format: 'JSON')
  end

  def create_document(extracted_text, saved_response, filename, process)
    Extraction::Document.new(
      url: saved_response['url'], method: saved_response['method'],
      params: saved_response['params'], request_headers: saved_response['request_headers'],
      status: saved_response['status'], response_headers: saved_response['response_headers'],
      body: { text: extracted_text, process: process }.to_json
    ).save("#{@extraction_folder}/#{filename}")
  end
end
