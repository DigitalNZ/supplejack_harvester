# frozen_string_literal: true

class TextExtractionWorker < FileExtractionWorker
  def process_extracted_documents
    Dir.children(@tmp_directory).each do |folder|
      process_text_folder(folder)
    end

    @extraction_definition.update(format: 'JSON')
  end

  def process_text_folder(folder)
    Dir.children("#{@tmp_directory}/#{folder}").each do |file|
      process_text_file(folder, file)
    end
  rescue StandardError => text_error
    handle_text_extraction_error(text_error)
  end

  def process_text_file(folder, file)
    loaded_file = File.read("#{@tmp_directory}/#{folder}/#{file}")
    extracted_text = extract_text(loaded_file, file, folder)
    filepath = "#{@extraction_folder}/#{folder}/#{file}"
    create_document(extracted_text[:text], filepath, extracted_text[:process])
    @page += 1
  end

  def handle_text_extraction_error(error)
    JobCompletionServices::ContextBuilder.create_job_completion_or_error({
                                                                           error: error,
                                                                           definition: @extraction_definition,
                                                                           job:
                                                                             @extraction_definition
                                                                               .extraction_jobs.first,
                                                                           origin: 'TextExtractionWorker'
                                                                         })
    raise
  end

  def create_document(extracted_text, filepath, process)
    Extraction::Document.new(
      url: saved_response['url'], method: saved_response['method'],
      params: saved_response['params'], request_headers: saved_response['request_headers'],
      status: saved_response['status'], response_headers: saved_response['response_headers'],
      body: { text: extracted_text, process: }.to_json
    ).save(filepath)
  end

  private

  def extract_text(loaded_file, file, folder)
    mimetype = Marcel::MimeType.for(loaded_file)

    text = Yomu.read(:text, loaded_file)
    process = "Extracted from #{mimetype} using Yomu"

    if text.squish.empty? && mimetype == 'application/pdf'
      text = ocr_pdf(file, folder)
      process = 'Extracted from PDF using OCRmyPDF'
    end

    { text:, process: }
  end

  def ocr_pdf(file, folder)
    base_file_name = File.basename(file, File.extname(file))

    `ocrmypdf \
      "#{@tmp_directory.shellescape}/#{folder.shellescape}/#{file.shellescape}" \
      --sidecar "#{@tmp_directory.shellescape}/#{folder.shellescape}/#{base_file_name.shellescape}.txt" - \
      --redo-ocr --output-type=none -q`

    if File.exist?("#{@tmp_directory}/#{folder}/#{base_file_name}.txt")
      File.read("#{@tmp_directory}/#{folder}/#{base_file_name}.txt")
    else
      'OCR failed'
    end
  end

  def saved_response
    { 'method' => 'GET', 'status' => 200, 'response_headers' => [], 'request_headers' => [] }
  end
end
