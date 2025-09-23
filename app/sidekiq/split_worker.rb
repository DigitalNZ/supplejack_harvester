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
        extraction_info = Supplejack::JobCompletionSummaryLogger.extract_from_extraction_definition(@extraction_definition)
        return unless extraction_info

        harvest_job = @extraction_job.harvest_job
        Supplejack::JobCompletionSummaryLogger.log_completion(
          worker_class: 'SplitWorker',
          exception: e,
          extraction_id: extraction_info[:extraction_id],
          extraction_name: extraction_info[:extraction_name],
          details: {
            extraction_job_id: @extraction_job.id,
            extraction_definition_id: @extraction_definition.id,
            harvest_job_id: harvest_job&.id,
            harvest_report_id: harvest_job&.harvest_report&.id,
            folder: folder,
            file: file,
            split_selector: @extraction_definition.split_selector
          }
        )
        raise
      end
    end
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
