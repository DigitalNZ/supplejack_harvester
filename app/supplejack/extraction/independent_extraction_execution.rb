# frozen_string_literal: true

module Extraction
  class IndependentExtractionExecution
    def initialize(extraction_job)
      @job = extraction_job
      @definition = extraction_job.extraction_definition
      @harvest_report = extraction_job.harvest_job&.harvest_report
    end

    def call
      @job.independent_extraction_job_id.present? ? process_from_previous : process_initial
    rescue StandardError => e
      JobCompletionServices::ContextBuilder.create_job_completion_or_error(
        error: e, definition: @definition, job: @job, origin: 'IndependentExtractionExecution'
      )
      raise
    end

    private

    def process_initial
      extraction = IndependentExtraction.new(@definition.requests.first, @job.extraction_folder)
      extraction.extract
      return if extraction.document.blank?

      save_extracted_links(extraction)
    end

    def process_from_previous
      previous_docs = ExtractionJob.find(@job.independent_extraction_job_id).documents

      if @job.independent_extraction?
        process_links_from_documents(previous_docs)
      else
        process_content_from_documents(previous_docs)
      end
    end

    def process_links_from_documents(documents)
      page = 0
      each_link_url(documents) do |url|
        extraction = fetch_url(url)
        next unless extraction.document&.successful?

        page = save_links_from_extraction(extraction, page)
      end
      update_harvest_report_timestamp
    end

    def process_content_from_documents(documents)
      page = 0
      each_link_url(documents) { |url| page = save_content_from_url(url, page) }
      update_harvest_report_timestamp
    end

    def save_links_from_extraction(extraction, page)
      extraction.extract_links(link_selector).each do |link|
        page += 1
        extraction.save_link(link, page, @definition.base_url)
        @harvest_report&.increment_pages_extracted!
      end
      page
    end

    def save_content_from_url(url, page)
      extraction = fetch_url(url)
      return page unless extraction.document&.successful?

      page += 1
      @definition.page = page
      extraction.save
      @harvest_report&.increment_pages_extracted!
      enqueue_transformation
      page
    end

    def update_harvest_report_timestamp
      @harvest_report&.update(extraction_updated_time: Time.zone.now)
    end

    def each_link_url(documents)
      (1..documents.total_pages).each do |n|
        break if @job.reload.cancelled?

        url = extract_url_from_document(documents[n])
        next if url.blank?

        yield url
        sleep @definition.throttle / 1000.0
      end
    end

    def extract_url_from_document(doc)
      return nil unless doc

      body = JSON.parse(doc.body)
      body['url'] if body.is_a?(Hash) && body.keys == ['url']
    rescue JSON::ParserError
      nil
    end

    def fetch_url(url)
      extraction = IndependentExtraction.new(@definition.requests.first, @job.extraction_folder, @definition.page, url)
      extraction.extract
      extraction
    end

    def save_extracted_links(extraction)
      extraction.extract_links(link_selector).each_with_index do |link, i|
        extraction.save_link(link, i + 1, @definition.base_url)
        @harvest_report&.increment_pages_extracted!
      end

      update_harvest_report_timestamp
    end

    def link_selector
      AutomationStep.find_by(independent_extraction_job_id: @job.id)&.link_selector
    end

    def enqueue_transformation
      return unless (harvest_job = @job.harvest_job)

      TransformationWorker.perform_async_with_priority(harvest_job.pipeline_job.job_priority, harvest_job.id,
                                                       @definition.page)
      @harvest_report&.increment_transformation_workers_queued!
    end
  end
end
