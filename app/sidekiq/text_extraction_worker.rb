# frozen_string_literal: true

class TextExtractionWorker < FileExtractionWorker
  def process_extracted_documents
    Dir.children(@tmp_directory).each do |folder|
      Dir.children("#{@tmp_directory}/#{folder}").each do |file|
        loaded_file = File.read("#{@tmp_directory}/#{folder}/#{file}")

        extracted_text = extract_text(loaded_file, file, folder)
        filepath = "#{@extraction_folder}/#{folder}/#{file}"
        create_document(extracted_text[:text], filepath, extracted_text[:process])
        @page += 1
      rescue StandardError => e
        log_text_extraction_error(e, folder, file)
        raise
      end
    end

    @extraction_definition.update(format: 'JSON')
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

  def log_text_extraction_error(exception, folder, file)
    return unless @extraction_definition&.harvest_definition&.source_id

    JobCompletionSummary.log_error(
      extraction_id: @extraction_definition.harvest_definition.source_id,
      extraction_name: @extraction_definition.harvest_definition.name,
      message: "TextExtractionWorker error: #{exception.class} - #{exception.message}",
      details: {
        worker_class: self.class.name,
        exception_class: exception.class.name,
        exception_message: exception.message,
        stack_trace: exception.backtrace&.first(20),
        extraction_job_id: @extraction_job.id,
        extraction_definition_id: @extraction_definition.id,
        harvest_job_id: @extraction_job.harvest_job&.id,
        harvest_report_id: @extraction_job.harvest_job&.harvest_report&.id,
        folder: folder,
        file: file,
        file_extension: File.extname(file),
        timestamp: Time.current.iso8601
      }
    )
  rescue StandardError => e
    Rails.logger.error "Failed to log text extraction error to JobCompletionSummary: #{e.message}"
  end
end
