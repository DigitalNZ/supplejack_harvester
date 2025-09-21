# frozen_string_literal: true

class SplitWorker < FileExtractionWorker
  def process_extracted_documents
    Dir.children(@tmp_directory).each do |folder|
      Dir.children("#{@tmp_directory}/#{folder}").each do |file|
        saved_response = JSON.parse(File.read("#{@tmp_directory}/#{folder}/#{file}"))

        Nokogiri::XML(saved_response['body']).xpath(@extraction_definition.split_selector).each_slice(100) do |records|
          create_document(records, saved_response)
          @page += 1
        end
      rescue StandardError => e
        log_split_worker_error(e, folder, file)
        raise
      end
    end
  end

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

  private

  def log_split_worker_error(exception, folder, file)
    return unless @extraction_definition&.harvest_definition&.source_id

    JobCompletionSummary.log_error(
      extraction_id: @extraction_definition.harvest_definition.source_id,
      extraction_name: @extraction_definition.harvest_definition.name,
      message: "SplitWorker error: #{exception.class} - #{exception.message}",
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
        split_selector: @extraction_definition.split_selector,
        timestamp: Time.current.iso8601
      }
    )
  rescue StandardError => e
    Rails.logger.error "Failed to log split worker error to JobCompletionSummary: #{e.message}"
  end
end
