# frozen_string_literal: true

require 'nokogiri'
require 'jsonpath'

module Extraction
  # rubocop:disable Metrics/ClassLength
  class IndependentExtractionExecution
    def initialize(extraction_job)
      @job = extraction_job
      @definition = extraction_job.extraction_definition
      @harvest_report = extraction_job.harvest_job&.harvest_report
      @link_selector = AutomationStep.find_by(independent_extraction_job_id: extraction_job.id)&.link_selector
    end

    def call
      @job.independent_extraction_job_id.present? ? process_from_previous_job : process_from_page
    rescue StandardError => e
      JobCompletionServices::ContextBuilder.create_job_completion_or_error(
        error: e, definition: @definition, job: @job, origin: 'IndependentExtractionExecution'
      )
      raise
    end

    private

    def process_from_page
      extraction = IndependentExtraction.new(@definition.requests.first, @job.extraction_folder)
      extraction.extract
      return if extraction.document.blank?

      extract_links(extraction.document.body).each_with_index do |url, i|
        save_link_document(url, i + 1)
        @harvest_report&.increment_pages_extracted!
      end
      update_extraction_time
    end

    def process_from_previous_job
      previous_docs = ExtractionJob.find(@job.independent_extraction_job_id).documents
      @job.independent_extraction? ? extract_links_from_docs(previous_docs) : extract_content_from_docs(previous_docs)
    end

    def extract_links_from_docs(documents)
      page = 0
      each_url(documents) do |url|
        doc = fetch(url)
        extract_links(doc.body).each { |link| page = save_and_track_link(link, page) } if doc&.successful?
      end
      update_extraction_time
    end

    def save_and_track_link(link, page)
      save_link_document(link, page + 1)
      @harvest_report&.increment_pages_extracted!
      page + 1
    end

    def extract_content_from_docs(documents)
      page = 0
      each_url(documents) do |url|
        page += 1
        extraction = IndependentExtraction.new(@definition.requests.first, @job.extraction_folder, page, url)
        save_and_transform(extraction, page) if extraction.extract && extraction.document&.successful?
      end
      update_extraction_time
    end

    def save_and_transform(extraction, page)
      @definition.page = page
      extraction.save
      @harvest_report&.increment_pages_extracted!
      enqueue_transformation
    end

    def each_url(documents)
      (1..documents.total_pages).each do |n|
        break if @job.reload.cancelled?

        url = parse_url_from_doc(documents[n])
        next if url.blank?

        yield url
        sleep @definition.throttle / 1000.0
      end
    end

    def parse_url_from_doc(doc)
      JSON.parse(doc&.body)['url']
    rescue StandardError
      nil
    end

    def fetch(url)
      extraction = IndependentExtraction.new(@definition.requests.first, @job.extraction_folder, 1, url)
      extraction.extract
      extraction.document
    end

    def extract_links(body)
      return [] if @link_selector.blank? || body.blank?

      if @link_selector.start_with?('$')
        JsonPath.new(@link_selector).on(JSON.parse(body))
      else
        extract_from_html(body)
      end.compact_blank
    rescue JSON::ParserError, Nokogiri::SyntaxError
      []
    end

    def extract_from_html(body)
      doc = body.strip.start_with?('<?xml') ? Nokogiri::XML(body) : Nokogiri::HTML(body)
      nodes = @link_selector.start_with?('/') ? doc.xpath(@link_selector) : doc.css(@link_selector)

      nodes.filter_map { |n| link_value(n) }
    end

    def link_value(node)
      case node
      when Nokogiri::XML::Attr then node.value
      when Nokogiri::XML::Element then node['href'] || node['url'] || node.text.strip.presence
      when Nokogiri::XML::Text then node.text.strip
      end
    end

    def save_link_document(url, page_number)
      full_url = url.start_with?('http') ? url : URI.join(@definition.base_url, url).to_s

      folder = (page_number / Documents::DOCUMENTS_PER_FOLDER.to_f).ceil
      name = @definition.name.parameterize(separator: '_')
      path = "#{@job.extraction_folder}/#{folder}/#{name}__-__#{format('%09d', page_number)[-9..]}.json"

      Document.new(url: full_url, method: 'GET', params: {}, request_headers: {},
                   status: 200, response_headers: {}, body: { url: full_url }.to_json).save(path)
    end

    def enqueue_transformation
      return unless (harvest_job = @job.harvest_job)

      TransformationWorker.perform_async_with_priority(harvest_job.pipeline_job.job_priority, harvest_job.id,
                                                       @definition.page)
      @harvest_report&.increment_transformation_workers_queued!
    end

    def update_extraction_time
      @harvest_report&.update(extraction_updated_time: Time.zone.now)
    end
  end
  # rubocop:enable Metrics/ClassLength
end
