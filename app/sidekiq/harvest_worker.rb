# frozen_string_literal: true

class HarvestWorker < ApplicationWorker
  def child_perform(harvest_job)
    @harvest_job = harvest_job
    @pipeline_job = harvest_job.pipeline_job

    @harvest_report = HarvestReport.create(pipeline_job: @pipeline_job, harvest_job: @harvest_job,
                                           kind: @harvest_job.harvest_definition.kind,
                                           definition_name: @harvest_job.harvest_definition.name)

    if @pipeline_job.extraction_job.nil? || @harvest_job.harvest_definition.enrichment?
      create_extraction_job
    else
      create_transformation_jobs
    end
  end

  def create_extraction_job
    extraction_definition = @harvest_job.extraction_definition

    # Check if link extraction is enabled
    if extraction_definition.link_extraction_enabled?
      Rails.logger.info "[LinkExtraction] Link extraction enabled for harvest_job #{@harvest_job.id}, pipeline_job #{@pipeline_job.id}, extraction_definition #{extraction_definition.id}"
      Rails.logger.info "[LinkExtraction] Link selector: #{extraction_definition.link_selector}, format: #{extraction_definition.link_extraction_format}"
      create_link_extraction_jobs(extraction_definition)
    else
      Rails.logger.info "[LinkExtraction] Link extraction disabled, using normal flow for harvest_job #{@harvest_job.id}"
      # Normal flow: create single extraction job
      extraction_job = ExtractionJob.create(
        extraction_definition: extraction_definition,
        harvest_job: @harvest_job
      )

      ExtractionWorker.perform_async_with_priority(@pipeline_job.job_priority, extraction_job.id, @harvest_report.id)
    end
  end

  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  def create_link_extraction_jobs(extraction_definition)
    Rails.logger.info "[LinkExtraction] Starting link extraction for pipeline_job #{@pipeline_job.id}, harvest_job #{@harvest_job.id}"
    
    # Find source extraction job from previous automation step
    Rails.logger.info "[LinkExtraction] Looking for source extraction job..."
    source_extraction_job = @pipeline_job.source_extraction_job_for_link_extraction(extraction_definition)

    if source_extraction_job.blank?
      Rails.logger.warn "[LinkExtraction] No source extraction job found for pipeline_job #{@pipeline_job.id}"
      Rails.logger.warn "[LinkExtraction] Pipeline job from automation: #{@pipeline_job.from_automation?}"
      Rails.logger.warn "[LinkExtraction] Automation step: #{@pipeline_job.automation_step&.id}, position: #{@pipeline_job.automation_step&.position}"
      # Fall back to normal flow
      Rails.logger.info "[LinkExtraction] Falling back to normal flow (single extraction job)"
      extraction_job = ExtractionJob.create(
        extraction_definition: extraction_definition,
        harvest_job: @harvest_job
      )
      ExtractionWorker.perform_async_with_priority(@pipeline_job.job_priority, extraction_job.id, @harvest_report.id)
      return
    end

    Rails.logger.info "[LinkExtraction] Found source extraction job: #{source_extraction_job.id}, status: #{source_extraction_job.status}"
    Rails.logger.info "[LinkExtraction] Source extraction job documents count: #{source_extraction_job.documents.total_pages rescue 'error getting count'}"

    # Extract links from source extraction job
    Rails.logger.info "[LinkExtraction] Extracting links using selector: #{extraction_definition.link_selector}"
    links = LinkExtractionService.extract_links(source_extraction_job, extraction_definition)

    Rails.logger.info "[LinkExtraction] Extracted #{links.count} links"
    if links.any?
      Rails.logger.info "[LinkExtraction] First 5 links: #{links.first(5).inspect}"
    end

    if links.empty?
      Rails.logger.warn "[LinkExtraction] No links found for pipeline_job #{@pipeline_job.id}"
      Rails.logger.warn "[LinkExtraction] Falling back to normal flow (single extraction job)"
      # Fall back to normal flow
      extraction_job = ExtractionJob.create(
        extraction_definition: extraction_definition,
        harvest_job: @harvest_job
      )
      ExtractionWorker.perform_async_with_priority(@pipeline_job.job_priority, extraction_job.id, @harvest_report.id)
      return
    end

    # Filter valid URLs
    valid_links = links.select { |link| !link.blank? && valid_url?(link) }
    Rails.logger.info "[LinkExtraction] Valid links: #{valid_links.count} out of #{links.count} total"
    
    if valid_links.empty?
      Rails.logger.warn "[LinkExtraction] No valid URLs found after filtering"
      Rails.logger.warn "[LinkExtraction] Invalid links: #{links.reject { |l| l.blank? || valid_url?(l) }.first(5).inspect}"
      # Fall back to normal flow
      extraction_job = ExtractionJob.create(
        extraction_definition: extraction_definition,
        harvest_job: @harvest_job
      )
      ExtractionWorker.perform_async_with_priority(@pipeline_job.job_priority, extraction_job.id, @harvest_report.id)
      return
    end

    # Create an extraction job for each link
    Rails.logger.info "[LinkExtraction] Creating #{valid_links.count} extraction jobs..."
    created_count = 0
    valid_links.each do |link_url|
      begin
        # Create a temporary extraction definition clone with the link URL as base_url
        # This ensures each ExtractionJob has its own extraction_definition with the correct URL
        Rails.logger.info "[LinkExtraction] Creating extraction job for link: #{link_url}"
        temp_extraction_definition = create_temp_extraction_definition(extraction_definition, link_url)
        Rails.logger.info "[LinkExtraction] Created temp extraction definition: #{temp_extraction_definition.id} (#{temp_extraction_definition.name})"

        # Create extraction job with the temporary extraction definition
        extraction_job = ExtractionJob.create(
          extraction_definition: temp_extraction_definition,
          harvest_job: @harvest_job
        )
        Rails.logger.info "[LinkExtraction] Created extraction job: #{extraction_job.id} for link: #{link_url}"

        # Queue extraction worker in parallel
        ExtractionWorker.perform_async_with_priority(@pipeline_job.job_priority, extraction_job.id, @harvest_report.id)
        Rails.logger.info "[LinkExtraction] Queued ExtractionWorker for extraction_job #{extraction_job.id}"
        created_count += 1
      rescue StandardError => e
        Rails.logger.error "[LinkExtraction] Failed to create extraction job for link #{link_url}: #{e.class} - #{e.message}"
        Rails.logger.error "[LinkExtraction] Backtrace: #{e.backtrace.first(5).join("\n")}"
        next
      end
    end
    
    Rails.logger.info "[LinkExtraction] Successfully created #{created_count} extraction jobs out of #{valid_links.count} links"
  end

  def create_temp_extraction_definition(original_definition, link_url)
    # Clone the extraction definition with the link URL as base_url
    temp_definition = original_definition.dup
    temp_definition.base_url = link_url
    temp_definition.name = "#{original_definition.name}_link_#{SecureRandom.hex(4)}"
    temp_definition.save!

    # Clone requests from original definition
    original_definition.requests.each do |request|
      cloned_request = request.dup
      cloned_request.extraction_definition = temp_definition
      cloned_request.save!

      # Clone parameters
      request.parameters.each do |parameter|
        cloned_parameter = parameter.dup
        cloned_parameter.request = cloned_request
        cloned_parameter.save!
      end
    end

    temp_definition
  end

  def valid_url?(url)
    return false if url.blank?

    uri = URI.parse(url)
    uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    false
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength

  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  def create_transformation_jobs
    extraction_job = @pipeline_job.extraction_job
    @harvest_job.update(extraction_job_id: extraction_job.id)
    @harvest_report.extraction_completed!

    (extraction_job.extraction_definition.page..extraction_job.documents.total_pages).each do |page|
      @harvest_report.increment_pages_extracted!
      TransformationWorker.perform_in_with_priority(@pipeline_job.job_priority, (page * 5).seconds, @harvest_job.id,
                                                    page)
      @harvest_report.increment_transformation_workers_queued!

      @pipeline_job.reload
      break if @pipeline_job.cancelled? || page_number_reached?(page)
    end
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength

  private

  def page_number_reached?(page)
    @pipeline_job.set_number? && page == @pipeline_job.pages
  end
end
