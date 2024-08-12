# frozen_string_literal: true

class TextExtractionWorker < FileExtractionWorker
  def process_extracted_documents
    Dir.children(@tmp_directory).each do |file|
      loaded_file = File.read("#{@tmp_directory}/#{file}")

      extracted_text = extract_text(loaded_file, file)
      create_document(extracted_text[:text], file, extracted_text[:process])
      @page += 1
    end

    @extraction_definition.update(format: 'JSON')
  end

  def create_document(extracted_text, filename, process)
    Extraction::Document.new(
      url: saved_response['url'], method: saved_response['method'],
      params: saved_response['params'], request_headers: saved_response['request_headers'],
      status: saved_response['status'], response_headers: saved_response['response_headers'],
      body: { text: extracted_text, process: }.to_json
    ).save("#{@extraction_folder}/#{filename}")
  end

  private

  def extract_text(loaded_file, file)
    mimetype = Marcel::MimeType.for(loaded_file)

    text = Yomu.read(:text, loaded_file)
    process = "Extracted from #{mimetype} using Yomu"

    if text.squish.empty? && mimetype == 'application/pdf'
      text = ocr_pdf(file)
      process = 'Extracted from PDF using OCRmyPDF'
    end

    { text:, process: }
  end

  def ocr_pdf(file)
    base_file_name = File.basename(file, File.extname(file))

    `ocrmypdf \
      "#{@tmp_directory.shellescape}/#{file.shellescape}" \
      --sidecar "#{@tmp_directory.shellescape}/#{base_file_name.shellescape}.txt" - \
      --redo-ocr --output-type=none -q`

    if File.exist?("#{@tmp_directory}/#{base_file_name}.txt")
      File.read("#{@tmp_directory}/#{base_file_name}.txt")
    else
      'OCR failed'
    end
  end

  def saved_response
    { 'method' => 'GET', 'status' => 200, 'response_headers' => [], 'request_headers' => [] }
  end
end
